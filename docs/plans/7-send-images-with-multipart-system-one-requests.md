---
id: 7
slug: send-images-with-multipart-system-one-requests
title: "Send images with multipart System One requests"
kind: exec-plan
created_at: 2026-10-21T17:50:12Z
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-10-21T17:50:12Z
  revisions:
    - model: "claude-opus-5-5"
      harness: "claude-code"
      at: 2026-10-21T18:07:26Z
      mode: "update"
      note: "Apply haskell-jitsurei conventions: GHC2024 baseline, NoFieldSelectors, explicit Generic deriving, NamedRoutes, Int counts, plain assets Map"
  reviews:
    - model: "claude-fable-5-1"
      harness: "claude-code"
      at: 2026-10-22T03:15:28Z
      verdict: "comments"
      note: "Not a registry child; prerequisite framing consistent; inherits the refuted record-dot-on-NamedRoutes premise from EP-4"
---

# Send images with multipart System One requests

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.

**Prerequisite: do not start this plan until the whole of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md) is complete.** That means child plans EP-1 to EP-6 (`docs/plans/1-…` to `docs/plans/6-…`) are all marked Complete in its Exec-Plan Registry, and `typesafe-hs` 0.1.0.0 is on Hackage.

This plan is deliberately not a child of that MasterPlan. It is follow-up work, and the MasterPlan excluded it from the first release on 2026-10-21.

**Before implementation, the user must confirm two design choices in the Decision Log:**

- where the multipart code lives;
- whether it uses a hand-written encoder or `servant-multipart`.

Both choices bear on the dependency scope that requirements R1 and R12 of [docs/initial-spec.md](../initial-spec.md) fix.


## Purpose / Big Picture

Today the library can attach an image to a System One request only inline. An `Asset` carries the image bytes as base64 text in the JSON body (`data_base64`). That inflates the body by a third, and the whole image has to be base64-encoded in memory before sending.

The System One API also accepts a `multipart/form-data` body:

- The first part, named `request`, holds the ordinary JSON request with content type `application/json`.
- Each image follows as its own binary part.
- The JSON's `assets` map points each placeholder at an image part by name, with `{"type": "image", "part": "<part name>"}`.
- Requests that carry images must send the header `TypeSafe-Danger-Zone-Images: true`.

After this plan, a Haskell program can:

1. build a `MultipartRequest` from a `SystemOneRequest` and a list of in-memory images;
2. check it with a pure function;
3. see the exact bytes that will be sent;
4. call `POST /v1/systemone` with those bytes through servant-client.

To see it working:

- Run the test suite. A golden test compares the encoded body byte for byte against a checked-in file.
- A loopback mock server receives a multipart request sent through the servant client. It confirms that the body bytes, the content type including its boundary, and the `TypeSafe-Danger-Zone-Images` header are exactly as expected.
- Optionally, run the live example in Milestone 4 with an API key, and see a box answer come back for an image sent as a part.


## Progress

- [ ] Milestone 0: the user has confirmed the packaging and encoder decisions in the Decision Log (entries marked "Pending user confirmation" are resolved).
- [ ] Milestone 1: the pure multipart model and encoder exist in `TypeSafe.Wire.Multipart`. `cabal test` passes the new golden test, which compares against `test/golden/multipart-request.bytes`, and the validation tests.
- [ ] Milestone 2: the servant binding exists. A multipart request sent through `TypeSafe.V1`'s new multipart function reaches the loopback mock server with byte-identical body, the expected `Content-Type` and `TypeSafe-Danger-Zone-Images: true`.
- [ ] Milestone 3: conformance covers multipart. `multipart/form-data` is removed from the conformance suite's content-type exclusion list, and the suite checks that the binding matches the operation's `multipart/form-data` schema and `encoding`.
- [ ] Milestone 4: release readiness is in place. ADR 0004 is updated, `CHANGELOG.md` and the version are bumped to 0.1.1.0, `cabal check` and `cabal sdist` are clean, and the upload has been performed with the user's confirmation.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision (Pending user confirmation): implement multipart with a hand-written, pure encoder inside the core `typesafe-hs` package. Do not use `servant-multipart-api` or `servant-multipart-client`, and do not create a separate package or sublibrary.

  Rationale: a hand-written encoder of RFC 7578 `multipart/form-data` needs only `bytestring`, `text` and `aeson`, all already in R1's dependency list. The core package therefore keeps R1's dependency list unchanged, and R12's bounds stay valid for Baikai. That removes the reason for a separate component. `servant-multipart` would be a poor fit in any case:
  - Its `inputs` are written without a per-part `Content-Type`, but the specification's `encoding.request.contentType` is `application/json`.
  - It writes all `inputs` before all `files` in its own order, so we could not guarantee that the `request` part comes first.
  - Its client instance for the `Tmp` backend, which Mercury's `openai` package uses, reads files from disk. Mercury's `openai` uses `servant-multipart-api` and `servant-multipart-client` (`mori://MercuryTechnologies/openai`, project-relative paths `openai.cabal` lines 41 and 44, `src/OpenAI/V1/Files.hs` lines 37-48 and `src/OpenAI/V1.hs` lines 597-602; artifact-level URIs pending).
  - It would add two dependencies that Baikai's release gate would then have to resolve from Hackage.

  The alternative, if the user prefers library reuse, is a public sublibrary `typesafe-hs:multipart` that depends on `servant-multipart-api` and `servant-multipart-client`. That keeps the core library's dependency closure unchanged, but adds a second component that EP-6's release checks must cover. Choosing it would change R1 and R12 for that component only, and it needs the user's explicit approval.
  Date: 2026-10-21

- Decision (Pending user confirmation): use a fixed library boundary constant, `defaultBoundary`, in the static `Content-Type` of the servant content type. The encoder refuses, with an explicit error, any body in which the boundary would occur inside a part. Tests use `encodeMultipartWith` with an explicit boundary.

  Rationale: servant computes a request's `Content-Type` from the content type's `contentType` method, which cannot depend on the value. A per-request random boundary would therefore need a custom `HasClient` combinator. A long random constant has negligible collision probability, and the explicit check means a collision fails loudly instead of corrupting the body. Mercury's `openai` uses the same fixed-boundary approach (`src/OpenAI/V1.hs` lines 597-602).

  Determinism is also a benefit, as R3 values for JSON bodies: the same request always produces the same bytes, which Baikai-style evidence commitments rely on.

  The official TypeScript SDK, by contrast, draws a random 32-hex-digit boundary per request (local checkout `/Users/shinzui/Keikaku/hub/agents/typesafe-sdk-js`, `src/assets.ts` lines 23-26 and 318-340). The server accepts any boundary, so ours is a free choice.
  Date: 2026-10-21

- Decision: add the servant binding as a separate `NamedRoutes` record, `data MultipartRoutes mode = MultipartRoutes { systemOneMultipart :: mode :- SystemOneMultipartEndpoint }`, with `type MultipartAPI = NamedRoutes MultipartRoutes` and a standalone client function in `TypeSafe.V1`. Do not add a field to the existing `Routes` record, change `API`, or add a field to the exported `Methods` record. Release as 0.1.1.0.

  Rationale: haskell-jitsurei's servant pattern (`mori://shinzui/haskell-jitsurei/docs/api-servant-routes`) allows a route either as a new field or as a separate record, which is later mounted with `:<|>` if a combined API is ever wanted. Adding a field would be additive in spirit, but it is breaking under the Haskell Package Versioning Policy (PVP). `Routes (..)` and `Methods (..)` are exported with their constructors, so a consumer that builds a `Routes (AsServerT m)` server, as a loopback fixture does, or pattern-matches either record would stop compiling. That forces a major bump to 0.2.0.0. A new record, type and function are new exports only, a minor change, so 0.1.0.0 becomes 0.1.1.0. Folding the multipart route into `Routes` is left to a future major release.
  Date: 2026-10-21 (revised the same day from a positional `:<|>`-style `MultipartAPI` type to a `NamedRoutes` record)

- Decision: the new code follows the conventions the initiative adopted from haskell-jitsurei, recorded in `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`:
  - new records and sums use explicit `deriving stock (Generic, Eq, Show)`, and the exception uses `deriving stock (Show)` with `deriving anyclass (Exception)`;
  - qualified imports are postpositive;
  - fields in `TypeSafe.Wire.Multipart` have no selector functions (`NoFieldSelectors`) and are read with record dot syntax;
  - the multipart route field carries its own `Authorization` header, following jitsurei's "auth goes on the field, not the record";
  - the client is derived with `genericClientHoist`.

  Rationale: the core package's common stanza already enables `NoFieldSelectors`, `DeriveAnyClass` and the rest of the jitsurei baseline, and new modules must match. `NoFieldSelectors` matters concretely here. Otherwise `ImagePart`'s `contentType` field would generate a selector that clashes with servant's `Accept` class method `contentType`, which `TypeSafe.V1` uses for the `MultipartFormData` instance. `TypeSafe.V1` turns `FieldSelectors` back on only because `NamedRoutes` fields need selector application.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

**The files may have evolved.** This plan was written on 2026-10-21, before the code it builds on existed. Everything below describes what the MasterPlan's child plans were specified to deliver. Before editing, read the real files named here, along with the Decision Logs and Outcomes sections of `docs/plans/1-…` through `docs/plans/6-…`, and adjust names in this plan where the code differs. Record any such adjustment in Surprises & Discoveries.

**Repository and tools.** This repository is the Haskell package `typesafe-hs`, with the Cabal file `typesafe-hs.cabal` at the root and a `cabal.project`. It builds with GHC 9.12.4 inside the Nix development shell defined by `flake.nix` and `nix/haskell.nix`. Run every command from the repository root via `nix develop -c …`, or after `direnv allow`. Formatting uses fourmolu (`fourmolu.yaml`) through `nix fmt`.

**Terms used in this plan.**

- **Multipart.** `multipart/form-data` (RFC 7578) is an HTTP body format that carries several named "parts" in one body. Each part is introduced by a line `--<boundary>`, followed by:
  - its headers (`Content-Disposition: form-data; name="…"` and optionally `; filename="…"`, then `Content-Type: …`);
  - a blank line;
  - the raw bytes, then `\r\n`.

  The body ends with `--<boundary>--\r\n`.
- **Boundary.** The boundary is an ASCII string chosen by the sender that must not appear inside any part. It is announced in the request header `Content-Type: multipart/form-data; boundary=<boundary>`.
- **Servant.** Servant describes an HTTP API as a Haskell type. servant-client derives client functions from that type, and servant-server derives a server.
- **Content type in servant.** A servant "content type" is an empty data type with an `Accept` instance (its media type) and `MimeRender` and `MimeUnrender` instances (how to write and read a body).

**What the MasterPlan delivered, as specified.**

- **`spec/openapi.json`** is the vendored OpenAPI document (version label `0.2.0`, published copy of 2026-10-21). It defines `POST /v1/systemone` with two request body content types:
  - `application/json`, whose schema is `SystemOneRequest`;
  - `multipart/form-data`. Its schema is an object with a required `request` property (`contentMediaType: application/json`, `contentSchema: SystemOneRequest`) plus `additionalProperties` of `contentMediaType: image/*`, and `encoding.request.contentType` is `application/json`. Its description reads: "The JSON request as the first part, named request, then each image as its own part. Every image part needs a unique, non-empty name and must be used by exactly one asset's part."

  It also defines the header parameters `TypeSafe-Danger-Zone-Images` and `TypeSafe-Danger-Zone-Long-Context`, each with the enum `["true"]`. The `Asset` schema has no required properties: `type` (const `"image"`), `data_base64`, `format` (enum `png`, `jpg`, `jpeg`) and `part`. Its description says that "with part, data_base64 is ignored".
- **`src/TypeSafe/Wire/Common.hs`** (EP-1) holds the shared primitives:
  - `Content`, `ModelName` and `QuestionName`;
  - `apiSpecVersion`;
  - the constants `requestIdHeader`, `dangerZoneImagesHeader`, `dangerZoneLongContextHeader`, `systemOnePath`, `modelsPath` and `defaultBaseUrl`.

  `src/TypeSafe/Wire.hs` is the umbrella module that re-exports every wire module.
- **`src/TypeSafe/Wire/Request.hs`** (EP-2) holds the request types:
  - `SystemOneRequest { model, state, questions, assets }`, where `assets :: Map Text Asset` maps placeholder text to `Asset`. It is omitted from the JSON when empty, and an absent key decodes to `Map.empty`;
  - the `Question` sum type, including `QuestionBox`;
  - `Asset { dataBase64 :: Maybe Text, format :: Maybe …, part :: Maybe Text }`, with `type` implied;
  - `encodeSystemOneRequest :: SystemOneRequest -> Data.ByteString.Lazy.ByteString`, built on `toEncoding` with a fixed key order;
  - `duplicateQuestionNames` and `duplicateChoiceLabels`.

  Its golden files are `test/golden/baikai-request.json` and `test/golden/baikai-request.bytes`.
- **Project conventions** (EP-1, `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`). The common stanza in `typesafe-hs.cabal` enables `GHC2024` with `DeriveAnyClass`, `DuplicateRecordFields`, `NoFieldSelectors`, `OverloadedLabels`, `OverloadedRecordDot` and `OverloadedStrings`; this is the haskell-jitsurei baseline (`mori://shinzui/haskell-jitsurei/docs/core-standards`) plus the last two.
  - Wire-type fields have no selector functions. They are read with record dot syntax (`req.assets`) and constructed with record syntax.
  - Every exported wire type derives `Generic`, `Eq` and `Show` through explicit `deriving stock` clauses.
  - Qualified imports are postpositive (`import Data.Map.Strict qualified as Map`).
  - `-Werror=missing-fields` is set only in `cabal.project`.
- **EP-3** owns `src/TypeSafe/Wire/Response.hs`, `src/TypeSafe/Wire/Models.hs` and `src/TypeSafe/Wire/Error.hs`. They provide `SystemOneResponse` with `AnswerBox` and `BoxAnswer`, and `parseErrorBody`.
- **`src/TypeSafe/V1.hs`** (EP-4) holds the servant layer. It enables `{-# LANGUAGE FieldSelectors #-}` for itself, because record dot syntax cannot see through `NamedRoutes` fields. It provides:
  - the routes as a `NamedRoutes` record rather than a positional `:<|>` chain: `data Routes mode = Routes { systemOne :: mode :- SystemOneEndpoint, models :: mode :- ModelsEndpoint }` and `type API = NamedRoutes Routes`;
  - on each endpoint synonym, its own required strict `Authorization` header, then `"v1"` and the path;
  - optional danger-zone headers on `SystemOneEndpoint`;
  - a client derived with `genericClientHoist`;
  - the `Methods` record (`createSystemOne`, `listModels`, plus whatever variant EP-4 chose for the danger-zone flags);
  - `getClientEnv :: Text -> IO ClientEnv` and `makeMethods :: ClientEnv -> Text -> Methods`.

  EP-4's loopback mock server lives in `test/TypeSafe/Test/MockServer.hs`. It uses `servant-server` and `warp` and captures the raw request body and headers.
- **The conformance suite** (EP-5) checks the code against `spec/openapi.json`. It keeps an explicit list of request-body content types it deliberately does not bind, containing `multipart/form-data`, so that any other unbound content type fails the suite. Find the list by searching the test tree for `multipart/form-data`.
- **`test/Main.hs`** is the tasty test tree. Each feature registers one group there. The single test suite is `typesafe-hs-test`.

**ADRs.** `docs/adr/` holds this project's ADRs, established by EP-1 using the convention `NNNN-slug.md` with `title`, `status` and `date` frontmatter. Two are relevant here:

- **`docs/adr/0004-…`** records that the first release targets the current published document with JSON bodies only, and defers multipart to this plan. Its exact filename may differ, so list `docs/adr/` to find it. This plan must update it.
- **`docs/adr/0002-…`**, "the library carries no transport policy", still applies. The multipart function adds no retries, no timeouts, no environment lookups and no classification of failures, which surface as servant-client's `ClientError`.

**The reference implementation.** The official TypeScript SDK's multipart layout is in `src/assets.ts` lines 300-400 of the local checkout `/Users/shinzui/Keikaku/hub/agents/typesafe-sdk-js`, and its byte-level test is in `test/client.test.ts` lines 796-833. Each part is written as:

```text
--<boundary>\r\n
Content-Disposition: form-data; name="<name>"[; filename="<filename>"]\r\n
Content-Type: <content type>\r\n
\r\n
<bytes>\r\n
```

The body ends with `--<boundary>--\r\n`. The `request` part comes first, with no filename and content type `application/json`. Each image part sets `filename` equal to its name. Its content type is sniffed from the bytes: PNG and JPEG signatures give `image/png` and `image/jpeg`, and anything else gives `application/octet-stream`. Names and filenames are written unescaped, so they must be ASCII without double quotes or CR/LF.


## Plan of Work

### Milestone 0: confirm the design

Show the user the two Decision Log entries marked "Pending user confirmation" and ask them to choose:

- the core package with a hand-written encoder (recommended), or a `typesafe-hs:multipart` sublibrary using servant-multipart;
- the fixed boundary constant (recommended), or a per-request boundary through a custom servant combinator.

Record the answer by editing those entries. If the user chooses the sublibrary, the module names below stay the same but live under a `library multipart` stanza with `visibility: public`. Milestone 4 then also covers that component's bounds and `cabal check`. This milestone ends when the entries no longer say "Pending".

### Milestone 1: the pure multipart model and encoder

Create `src/TypeSafe/Wire/Multipart.hs`, add it to `exposed-modules` in `typesafe-hs.cabal`, and re-export it from `src/TypeSafe/Wire.hs`. It defines four things.

**The image part.**

```haskell
data ImagePart = ImagePart
  { name :: !Text,                    -- the part name an Asset's `part` refers to
    contentType :: !Text,             -- e.g. "image/png"; see imageContentType
    bytes :: !Data.ByteString.Lazy.ByteString
  }
  deriving stock (Generic, Eq, Show)
```

Under `NoFieldSelectors` these fields generate no top-level functions. In particular there is no `contentType` selector to clash with servant's `Accept` method in `TypeSafe.V1`.

**The multipart request.**

```haskell
data MultipartRequest = MultipartRequest
  { request :: !SystemOneRequest,
    images :: !(Vector ImagePart)     -- sent in this order, after the request part
  }
  deriving stock (Generic, Eq, Show)
```

**The problems a request can have.**

```haskell
data MultipartProblem
  = ImagePartNameEmpty
  | ImagePartNameInvalid Text         -- non-ASCII, contains '"', CR or LF
  | ImagePartNameDuplicate Text
  | ImagePartUnused Text              -- no asset's part names it
  | ImagePartUsedMoreThanOnce Text    -- several assets name it
  | AssetPartMissing Text Text        -- placeholder, part name with no image
  | BoundaryOccursInPart Text         -- part name ("request" or an image)
  deriving stock (Generic, Eq, Show)
```

**The functions.**

- `multipartProblems :: MultipartRequest -> [MultipartProblem]` is a pure validation that reports every rule the specification states.
- `encodeMultipartWith :: Text -> MultipartRequest -> Either MultipartProblem Data.ByteString.Lazy.ByteString` writes the `request` part first. Its bytes are exactly `encodeSystemOneRequest request`, under the headers `Content-Disposition: form-data; name="request"` and `Content-Type: application/json`. Then it writes each image in vector order, with `filename` equal to its name, and finally the closing delimiter. It returns `Left (BoundaryOccursInPart …)` when the boundary string occurs in any part's bytes.
- `encodeMultipart = encodeMultipartWith defaultBoundary`.
- `defaultBoundary :: Text` is a fixed ASCII string of about 48 random alphanumeric characters prefixed `typesafe-hs-`. Generate it once and paste it as a literal.
- `imageContentType :: Data.ByteString.Lazy.ByteString -> Text` sniffs the PNG signature (`89 50 4E 47 0D 0A 1A 0A`) and the JPEG signature (`FF D8 FF`), and otherwise returns `application/octet-stream`. This mirrors the TypeScript SDK.

**Validation in the encoder.** The encoder does not call `multipartProblems` itself, except for the boundary check it needs for correctness. This keeps the wire layer policy-free in the same way `duplicateQuestionNames` is a separate function. Document this in the Haddock.

**Building the body.** Use `Data.ByteString.Builder`. Never go through an intermediate `Value`, so that the JSON part is byte-equal to the JSON-body encoding.

**Tests.** Add `test/TypeSafe/Wire/MultipartSpec.hs` as a tasty group registered in `test/Main.hs`. It has three kinds of test.

- **A golden test.** Build a request with:
  - model `jev-preview`;
  - state `"Compare <a> with <b>"`;
  - one box question;
  - `assets` mapping `<a>` to part `asset-0` and `<b>` to part `asset-1`;
  - two images: the 3 bytes `FF D8 FF` as `image/jpeg`, and the 1x1-pixel PNG obtained by base64-decoding the `data_base64` in the specification's `box` request example.

  Encode it with the boundary `test-boundary`. The bytes must equal the checked-in `test/golden/multipart-request.bytes`. Write the golden by hand from the layout in Context and Orientation and inspect it with `xxd`. Do not generate it from the encoder under test.
- **A round-trip test.** Parse the encoded body back with `wai-extra`'s `Network.Wai.Parse.parseRequestBodyEx`, added as a test-only dependency. Assert that the part names come back in order (`request`, `asset-0`, `asset-1`), along with their filenames, content types and bytes. Assert also that the `request` part decodes to the original `SystemOneRequest`, comparing by value and ignoring question order.
- **Validation tests.** There is one case per `MultipartProblem` constructor, plus a boundary collision: an image whose bytes contain `--test-boundary` makes `encodeMultipartWith "test-boundary"` return `Left (BoundaryOccursInPart "asset-0")`.

### Milestone 2: the servant binding

**The content type.** In `src/TypeSafe/V1.hs`, add a servant content type:

```haskell
data MultipartFormData
instance Accept MultipartFormData where
  contentType _ = "multipart" // "form-data" /: ("boundary", <defaultBoundary as ByteString>)
instance MimeRender MultipartFormData EncodedMultipart where ...
instance MimeUnrender MultipartFormData EncodedMultipart where ...  -- raw bytes, for the mock server
```

`EncodedMultipart` is a newtype over the lazy `ByteString` produced by `encodeMultipart`. Making it a distinct type means the encoding error is handled before servant is involved.

The operators `//` and `/:` come from `Network.HTTP.Media`. If `servant` does not re-export them, add `http-media` to the library's `build-depends`. `servant` already depends on it, so the dependency closure is unchanged. Record it in the Decision Log, because R1 lists direct dependencies.

**The routes.** Define a separate `NamedRoutes` record so that the existing `Routes` record and `API` type keep their meaning (see the Decision Log for why this is not a new field on `Routes`):

```haskell
type SystemOneMultipartEndpoint =
  Header' '[Required, Strict] "Authorization" Text
    :> "v1" :> "systemone"
    :> Header' '[Required, Strict] "TypeSafe-Danger-Zone-Images" Text
    :> Header' '[Optional, Strict] "TypeSafe-Danger-Zone-Long-Context" Text
    :> ReqBody '[MultipartFormData] EncodedMultipart
    :> Post '[JSON] SystemOneResponse

data MultipartRoutes mode = MultipartRoutes
  { systemOneMultipart :: mode :- SystemOneMultipartEndpoint
  }
  deriving stock (Generic)

type MultipartAPI = NamedRoutes MultipartRoutes
```

Mirror `SystemOneEndpoint`'s header order exactly, so the two endpoints differ only in the images header being required and in the request content type. Re-read `TypeSafe.V1` first; if EP-4's order differs from the one shown here, follow EP-4. Derive the client the way `makeMethods` does, with `Servant.Client.Generic.genericClientHoist`, and read the field with selector application (`systemOneMultipart client`), because `TypeSafe.V1` has `FieldSelectors` on.

The long-context header should be modelled the way EP-4 modelled it for the JSON endpoint, so re-read `TypeSafe.V1` first. Images are always present in a multipart request, so the images header is always sent as `"true"`.

**The client function.** Add a standalone function, not a `Methods` field (see the Decision Log):

```haskell
createSystemOneMultipart :: ClientEnv -> Text -> MultipartRequest -> IO SystemOneResponse
```

Its second argument is the API token, sent as `Bearer <token>` exactly as `makeMethods` does. It calls `encodeMultipart`. On `Left problem` it throws a dedicated exception, `MultipartEncodingError MultipartProblem`, with an `Exception` instance, and nothing is sent. Otherwise it runs the servant-client function, and failures surface as servant-client's `ClientError` unchanged.

If EP-4 exposed the danger-zone flags as a record argument, accept the same record here and ignore its images flag. Otherwise, take `Bool` for long context. Pick whichever matches the existing style, and log the choice.

**Tests.** Extend `test/TypeSafe/Test/MockServer.hs`, or add a sibling, to serve `MultipartAPI` as a `MultipartRoutes (AsServerT Handler)` record, with a handler that records the raw body and headers and replies with the decoded `test/golden/baikai-response.json`. Then add a test to `test/TypeSafe/V1Spec.hs`, or whatever module EP-4 used, that calls `createSystemOneMultipart` against the loopback server. It asserts that:

- the captured body is byte-equal to `encodeMultipart` of the same value;
- the captured `Content-Type` is `multipart/form-data; boundary=<defaultBoundary>`;
- `TypeSafe-Danger-Zone-Images` is `true` and `Authorization` is `Bearer test-token`;
- the decoded response equals the golden.

A second test makes the server reply 422 with an `HTTPValidationError` body. It asserts that a `FailureResponse` is thrown and that its body parses with `parseErrorBody` to the validation form.

### Milestone 3: conformance covers multipart

In the conformance suite, remove `multipart/form-data` from the list of deliberately unbound request content types. Add a check that:

- the vendored operation's `multipart/form-data` schema requires `request` and declares it with `contentSchema` `#/components/schemas/SystemOneRequest`;
- `encoding.request.contentType` is `application/json`, which is what the encoder writes;
- the binding table now records `POST /v1/systemone` as bound for both `application/json` and `multipart/form-data`.

If the suite's JSON Schema keyword whitelist lacks `contentMediaType`, `contentSchema` or `encoding`, add them, with the semantics the check needs. The suite must still fail on any keyword it does not understand. After this milestone, the suite has no exclusions left, and a new content type appearing in the document makes it fail.

### Milestone 4: ADR, version and release

Update `docs/adr/0004-…`. Keep the original decision text, then either:

- add a dated section stating that multipart image upload is bound from 0.1.1.0 with a hand-written encoder and a fixed boundary, giving the reasons from this plan's Decision Log; or
- set its status to `superseded`, and add a new ADR `docs/adr/NNNN-multipart-requests-use-a-hand-written-encoder.md` with the next free number, which the old record links to.

Prefer the second if the original ADR's decision was "JSON only", since that decision is no longer true.

Then:

- bump `version:` in `typesafe-hs.cabal` to `0.1.1.0`;
- add a `CHANGELOG.md` entry listing the new exports (`TypeSafe.Wire.Multipart`, `MultipartAPI`, `createSystemOneMultipart`, `MultipartEncodingError`);
- run `cabal check`, `cabal sdist`, the Hackage-only consumer build EP-6 set up (re-read `docs/plans/6-…` for its exact commands), and `nix build`.

**Uploading.** Uploading to Hackage is outward-facing and irreversible. Upload a package candidate first, show it to the user, and publish only after the user explicitly confirms.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/typesafe-hs`.

Before starting, check that the MasterPlan is complete and that the files this plan builds on exist:

```bash
grep -n "Complete" docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ls src/TypeSafe/Wire src/TypeSafe/V1.hs docs/adr test/golden
grep -rn "multipart/form-data" test/
```

Expect all six registry rows to be Complete, and the `grep` over `test/` to show the conformance suite's exclusion entry.

Build and run only the multipart tests while developing (tasty's `-p` selects tests whose path matches the pattern):

```bash
nix develop -c cabal build all
nix develop -c cabal test typesafe-hs-test --test-show-details=direct --test-options='-p Multipart'
```

Inspect the golden file by eye while writing it:

```bash
xxd test/golden/multipart-request.bytes | head -20
```

The first line should begin with the bytes of `--test-boundary\r\nContent-Disposition: form-data; name="request"`:

```text
00000000: 2d2d 7465 7374 2d62 6f75 6e64 6172 790d  --test-boundary.
00000010: 0a43 6f6e 7465 6e74 2d44 6973 706f 7369  .Content-Disposi
```

Run the full suite and the release checks at the end:

```bash
nix develop -c cabal test all --test-show-details=direct
nix develop -c cabal check
nix develop -c cabal sdist
nix build
nix fmt
```

Expected: `cabal test` ends with `All N tests passed`, `cabal check` prints `No errors or warnings could be found in the package.`, and `nix build` exits 0.

Commit at each milestone with a Conventional Commits message and the plan trailer, for example:

```text
feat(multipart): encode System One requests as multipart/form-data

Add TypeSafe.Wire.Multipart with a pure, deterministic encoder whose
request part is byte-equal to encodeSystemOneRequest, and a golden test.

ExecPlan: docs/plans/7-send-images-with-multipart-system-one-requests.md
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

**Unit and golden tests.** `cabal test typesafe-hs-test --test-options='-p Multipart'` passes. In particular:

- the golden test confirms the exact bytes of `test/golden/multipart-request.bytes`;
- the round-trip test recovers parts `request`, `asset-0` and `asset-1` in that order with the right content types;
- the collision test returns `Left (BoundaryOccursInPart "asset-0")`.

**Producer/consumer check.** The mock-server test sends a `MultipartRequest` through `createSystemOneMultipart` to a `warp` server on a random loopback port. It observes:

- a body byte-equal to `encodeMultipart` of the same value;
- `Content-Type: multipart/form-data; boundary=<defaultBoundary>`;
- `TypeSafe-Danger-Zone-Images: true`;
- `Authorization: Bearer test-token`.

The client receives the golden response. Run this check as soon as Milestone 2's API type compiles, before writing any further variants: it is the one uncertain interaction, between servant's content-type header and a boundary parameter.

**Conformance.** The conformance suite passes with no content-type exclusions. Temporarily re-adding a fake content type, such as `text/plain`, to a scratch copy of the specification passed through `TYPESAFE_OPENAPI_SPEC` (if EP-5 supports that override; otherwise edit a scratch copy and point the loader at it) makes the suite fail.

**Live check (optional, outside required acceptance).** With a real key, run a small `cabal repl` session or example program. It reads `TYPESAFE_API_KEY` itself, because the library never does. It sends a box question about a PNG as a multipart part, using model `jev-preview`, and gets back an `AnswerBox`. This touches a paid external service, so do it only with the user's permission.

**Release.** `cabal check` is clean. `cabal sdist` produces `dist-newstyle/sdist/typesafe-hs-0.1.1.0.tar.gz`. EP-6's Hackage-only consumer build of that tarball succeeds.


## Idempotence and Recovery

- **Code and tests.** All code and test steps are additive and can be repeated. Rebuilding and re-running tests is always safe.
- **Golden file.** If the golden test fails after an intentional change to the layout, rewrite `test/golden/multipart-request.bytes` by hand and review the diff with `xxd`. Never regenerate it blindly from the encoder.
- **Boundary.** If a real-world image ever collides with `defaultBoundary`, the client throws `MultipartEncodingError` and sends nothing. The fix is to change the constant, which is a minor version bump, not to retry.
- **Hackage upload.** The upload in Milestone 4 cannot be undone, because Hackage versions are immutable. Use `cabal upload` without `--publish` to create a candidate first, and publish only after the user confirms. If a published release is broken, release 0.1.1.1 with the fix and mark 0.1.1.0 deprecated on Hackage, again with the user's approval.


## Interfaces and Dependencies

**Prerequisites.** The whole of `docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md` must be complete (EP-1 to EP-6). In particular this plan needs:

- `Asset` with a `part` field;
- `encodeSystemOneRequest`;
- `TypeSafe.V1` with its `Routes` record, `API = NamedRoutes Routes`, `SystemOneEndpoint`, `Methods`, `getClientEnv` and `makeMethods`;
- the jitsurei-aligned conventions in `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`;
- the loopback mock server;
- the conformance suite's content-type exclusion list;
- ADR 0004;
- the release checks from EP-6.

**New library interface.** All of it is in `TypeSafe.Wire.Multipart`, re-exported by `TypeSafe.Wire`:

```haskell
data ImagePart = ImagePart { name :: !Text, contentType :: !Text, bytes :: !Data.ByteString.Lazy.ByteString }
data MultipartRequest = MultipartRequest { request :: !SystemOneRequest, images :: !(Vector ImagePart) }
data MultipartProblem = ...   -- constructors listed in Milestone 1
multipartProblems :: MultipartRequest -> [MultipartProblem]
encodeMultipartWith :: Text -> MultipartRequest -> Either MultipartProblem Data.ByteString.Lazy.ByteString
encodeMultipart :: MultipartRequest -> Either MultipartProblem Data.ByteString.Lazy.ByteString
defaultBoundary :: Text
imageContentType :: Data.ByteString.Lazy.ByteString -> Text
```

**New servant interface,** in `TypeSafe.V1`:

```haskell
data MultipartFormData                         -- servant content type
newtype EncodedMultipart = EncodedMultipart Data.ByteString.Lazy.ByteString
type SystemOneMultipartEndpoint = ...          -- shown in Milestone 2
data MultipartRoutes mode = MultipartRoutes { systemOneMultipart :: mode :- SystemOneMultipartEndpoint }
type MultipartAPI = NamedRoutes MultipartRoutes
newtype MultipartEncodingError = MultipartEncodingError MultipartProblem
  deriving stock (Show)
  deriving anyclass (Exception)
createSystemOneMultipart :: ClientEnv -> Text -> MultipartRequest -> IO SystemOneResponse
```

**Dependencies.** Under the recommended design, the library gains no new dependency outside R1's list (`base`, `aeson`, `bytestring`, `containers`, `scientific`, `text`, `vector`, `http-types`, `servant`, `servant-client`, plus what servant-client brings). The one possible addition is a direct `http-media` dependency, which is already in servant's closure. The test suite gains `wai-extra`, for `Network.Wai.Parse`.

Under the alternative design, a `typesafe-hs:multipart` sublibrary would add `servant-multipart-api` and `servant-multipart-client`. Mori's registry has no local source for them as of 2026-10-21, so read them from Hackage and check the latest versions on Hackage before choosing bounds.

**Versioning.** Under the PVP the release is 0.1.1.0: new modules and exports only, with `Routes`, `API` and `Methods` unchanged. Adding a field to `Routes` or `Methods` would instead be a major change, to 0.2.0.0.

Revision note (2026-10-21): aligned with the initiative's haskell-jitsurei change set.
- The summary of prior deliverables now reflects EP-4's `NamedRoutes` `Routes` record, which replaces the positional `:<|>` chain, and `assets :: Map Text Asset`, omitted when empty.
- It also reflects `NoFieldSelectors`, explicit deriving strategies and postpositive imports.
- The multipart binding is now a separate `MultipartRoutes` record served as `NamedRoutes`, rather than a new `Routes` field, which keeps the release a minor 0.1.1.0 bump.
