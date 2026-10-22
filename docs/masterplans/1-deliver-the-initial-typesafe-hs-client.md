---
id: 1
slug: deliver-the-initial-typesafe-hs-client
title: "Deliver the initial typesafe-hs client"
kind: master-plan
created_at: 2026-10-21T17:48:29Z
intention: "intention_01m5frxsb3e9et3b9mn8e31r8c"
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-10-21T17:48:29Z
  revisions:
    - model: "claude-opus-5-5"
      harness: "claude-code"
      at: 2026-10-21T18:07:26Z
      mode: "update"
      note: "Adopt haskell-jitsurei conventions and idiom-review changes across child plans; ADR 0005 records declined patterns"
    - model: "claude-fable-5-1"
      harness: "claude-code"
      at: 2026-10-22T03:32:09Z
      mode: "update"
      note: "Apply the 2026-10-22 review: -Werror flags confined to cabal.project, FieldSelectors exception dropped after the record-dot premise was refuted, Integration Points gaps closed, test-module naming and time bound fixed"
  reviews:
    - model: "claude-fable-5-1"
      harness: "claude-code"
      at: 2026-10-22T03:15:28Z
      verdict: "changes-requested"
      note: "Decomposition sound; EP-5 puts -Werror=incomplete-patterns in the .cabal test stanza, contradicting EP-6 acceptance and Integration Points; the EP-4/EP-5 record-dot-on-NamedRoutes premise is refuted on GHC 9.12.4 with servant 0.20.3"
---

# Deliver the initial typesafe-hs client

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

When this initiative is complete, this repository will contain a Haskell library, the Cabal package `typesafe-hs`, that a program can use to talk to TypeSafe's System One API at `https://api.typesafe.ai`. The API has two operations. `POST /v1/systemone` takes a piece of content (the "state") and a set of named questions, and returns one probabilistic answer per question. `GET /v1/models` lists the available models. The library will be published on Hackage, so that the first consumer, the `baikai-typesafe` provider in `mori://shinzui/baikai/plans/84-deliver-the-typesafe-system-one-provider-and-judgment-catalog`, can depend on it without any adapter-side workarounds.

The governing requirements are R1 to R12 in [docs/initial-spec.md](../initial-spec.md). Read that file first; this MasterPlan does not repeat them. In short, after the initiative:

- **Wire types.** A program can build a `SystemOneRequest` from plain Haskell values and get the exact, deterministic bytes that will be sent. It can decode a reply without losing any digits of a number. It gets a decoding failure when a required field is missing. It gets an explicit "other" constructor, not a silent drop, when the service returns a question or answer type the library does not know.
- **Error bodies.** A program can parse every error body the service is known to produce.
- **Models.** A program can decode the model listing.
- **Calling the API.** A program can call both operations through a servant `API` type and a servant-client `makeMethods`, in the shape of the Mercury `openai` and `claude` packages. Failures surface as servant-client's unmodified `ClientError`.
- **Conformance.** A test suite proves the Haskell codecs match the vendored OpenAPI document schema by schema and property by property. A script reports when the published document has drifted from the vendored copy.

**Protocol baseline.** The baseline is the OpenAPI document published at https://api.typesafe.ai/openapi.json as of 2026-10-21, vendored at `spec/openapi.json`. Its `info.version` is `0.2.0`. That published document has grown beyond the copy `docs/initial-spec.md` was written against (see Surprises & Discoveries): it now also defines box questions and answers, image assets, two optional request headers and a multipart request body. The user chose, on 2026-10-21, to target the current published document with JSON request bodies only. Every schema in it, including `BoxQuestion`, `BoxAnswer`, `BoxCoordinates` and `Asset`, gets a Haskell type. The optional `TypeSafe-Danger-Zone-Images` and `TypeSafe-Danger-Zone-Long-Context` request headers are bound in the servant API.

**Exclusions.** The following are outside this initiative:

- **Multipart image upload.** The `multipart/form-data` request body of `POST /v1/systemone`, where each image travels as its own part, is deliberately excluded from the first release. Images can still be sent inline, with `Asset.data_base64` in a JSON body. The follow-up work is planned, outside this MasterPlan, in [docs/plans/7-send-images-with-multipart-system-one-requests.md](../plans/7-send-images-with-multipart-system-one-requests.md).
- **Policy, per R1.** Retries, status classification, timeout policy, environment lookups, logging hooks and a typed question layer.
- **Changes to the Baikai repository.**


## Decomposition Strategy

The library has three natural layers:

- the wire types and their JSON codecs;
- a servant binding of the two operations over those types;
- the proofs that the first two match the specification and can be released.

The wire layer splits again along the direction of traffic. The request side's hard problem is deterministic, order-preserving encoding (R3). The response side's hard problems are lossless numbers, strict required fields, surfaced unknown tags and error-body parsing (R4, R5, R6, R9). These two halves share only a small set of primitives: the `Content` union, the name newtypes, the constants and `apiSpecVersion`. So a scaffold plan defines those primitives together with the package, the vendored document and the test harness. After it, the request and response plans can proceed in parallel.

The resulting child plans are:

- **EP-1, scaffold.** The package, the vendored specification, the drift script, the shared primitives, the test harness and the project's ADR corpus.
- **EP-2, requests.** Request types and deterministic encoding, including the request half of Baikai's golden fixture (R2, R3, R7, R8, R11).
- **EP-3, responses.** Response, model-listing and error-body types and decoding, including the response half of the golden fixture (R4, R5, R6, R9, R11).
- **EP-4, servant binding.** The servant `API`, `Methods`, `getClientEnv` and `makeMethods`, proven against a loopback mock server built from the same `API` type (R1, R3's byte-equality clause).
- **EP-5, conformance.** The suite against `spec/openapi.json`: binding table, a small JSON Schema validator, required and optional checks, discriminator checks and examples (R10).
- **EP-6, release.** Packaging and release readiness for Hackage: metadata, bounds intersecting Baikai's, an isolated build from the source distribution, and the upload itself, which needs the user's confirmation (R12).

Alternatives considered:

- **One plan for the whole wire layer.** Rejected because it would hold most of the initiative's work and hide the parallelism between request and response codecs.
- **Spreading conformance across EP-2 and EP-3.** Rejected because the JSON Schema reader, validator and binding table are one piece of machinery. Splitting it would duplicate it or create a hidden ordering. EP-2 and EP-3 still prove their own behaviour with hand-written and golden tests, so each is verifiable without EP-5.
- **Folding the scaffold into EP-2.** Rejected because EP-3 would then wait on all of EP-2 instead of on the small shared primitives.

**ADRs.** This repository has no `docs/adr/` directory yet, and `mori.dhall` declares no OKF ADR bundle, so there is no local ADR to cite. EP-1 establishes the corpus, following the plain filesystem convention used by the sibling Baikai repository: `docs/adr/NNNN-slug.md` with `title`, `status` and `date` frontmatter. Two Baikai decisions shape R1 and are cited as Mori has no artifact-level handles for them; searching Mori's concept registry on 2026-10-21 found none. They are referenced as `mori://shinzui/baikai` with project-relative paths `docs/adr/0005-what-baikai-deliberately-does-not-do.md` and `docs/adr/0011-core-owns-transport-failure-classification.md` (artifact-level URIs pending). Together they mean:

- Baikai classifies retryability but never retries.
- Baikai's core, not any provider dependency, maps transport failures to categories.

That is why this library must surface raw `ClientError` and status codes without interpretation.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Scaffold the package and vendor the System One specification | docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md | None | None | Not Started |
| 2 | Encode System One requests deterministically | docs/plans/2-encode-system-one-requests-deterministically.md | EP-1 | None | Not Started |
| 3 | Decode System One responses, model listings and error bodies | docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md | EP-1 | None | Not Started |
| 4 | Bind the System One API with servant and servant-client | docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md | EP-2, EP-3 | None | Not Started |
| 5 | Prove conformance with the vendored OpenAPI document | docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md | EP-2, EP-3, EP-4 M1 | EP-4 | Not Started |
| 6 | Prepare the first Hackage release of typesafe-hs | docs/plans/6-prepare-the-first-hackage-release-of-typesafe-hs.md | EP-4, EP-5 | None | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).
A whole-child hard dependency requires that child to be Complete. If only a milestone's
accepted output is needed, name it explicitly (e.g., EP-1 M1) and explain it below.

`docs/plans/7-send-images-with-multipart-system-one-requests.md` is deliberately not a child of this MasterPlan. It is deferred follow-up work, starting after this initiative completes, so it is not tracked in this registry.


## Dependency Graph

EP-1 comes first. Every other plan needs the Cabal package, the test harness, the vendored `spec/openapi.json` and the shared primitives in `TypeSafe.Wire.Common`.

EP-2 and EP-3 then proceed in parallel. They share only EP-1's primitives and touch disjoint modules. Their only shared files are the export list of the umbrella module `TypeSafe.Wire`, the Cabal module lists and the test-tree registration in `test/Main.hs`. Each change there is an additive one-line edit that merges trivially.

EP-4 depends on all of EP-2 and EP-3. The servant `API` type mentions `SystemOneRequest`, `SystemOneResponse` and `ModelMetadataList`, and its tests need:

- request encoding, for the byte-equality check;
- response encoding, so the mock server can reply;
- error-body parsing, to inspect the `FailureResponse`.

EP-5 depends on all of EP-2 and EP-3 because it binds every schema to a type and exercises both codec directions. It also depends on EP-4's Milestone 1 ("EP-4 M1"). That milestone's accepted output is the `TypeSafe.V1` module exporting `API` (`NamedRoutes Routes`), the route record `Routes (..)` with fields `systemOne` and `models`, and the endpoint types `SystemOneEndpoint` and `ModelsEndpoint`, all compiling in the library. EP-5 needs it only for its "every operation is bound" check. EP-5's schema-level milestones may therefore start as soon as EP-2 and EP-3 are complete, running alongside EP-4. Only EP-5's operation-binding milestone waits for EP-4 M1.

EP-6 depends on all of EP-4 and EP-5. The release candidate must contain the whole surface and pass the whole suite.

```text
EP-1 ──┬──> EP-2 ──┬──> EP-4 ──────────────┬──> EP-6
       └──> EP-3 ──┤      (M1) ──> EP-5 ───┘
                   └─────────────> EP-5
```


## Integration Points

**`typesafe-hs.cabal` and `cabal.project`.**
- *Plans:* all.
- *Owner:* EP-1 defines the package: a common stanza with `GHC2024`; the haskell-jitsurei baseline extensions `DeriveAnyClass`, `DuplicateRecordFields`, `OverloadedLabels` and `OverloadedStrings`; this project's additions `NoFieldSelectors` and `OverloadedRecordDot`; and `-Wall`. `MultilineStrings` is on in the test suite only. Every `-Werror=` flag lives in the `package typesafe-hs` stanza of `cabal.project`, which covers the library and the test suite alike, and never in the `.cabal` file, so `cabal check` stays clean. EP-1 sets `-Werror=missing-fields` there and EP-5 adds `-Werror=incomplete-patterns` there. The package itself has the `library`, with `hs-source-dirs: src`, and one `test-suite typesafe-hs-test` using `tasty`, with `hs-source-dirs: test` and `main-is: Main.hs`.
- *Later plans:* add their modules to `exposed-modules` or `other-modules`, and add their dependencies to the right stanza. A plan that owns golden files adds them to `extra-source-files` in the same change (EP-2, EP-3 and EP-4); EP-6 collapses the entries to globs and checks that the source distribution carries them.
- *Bounds:* library bounds must stay inside R12's list. A new library dependency must also be justified in that plan's Decision Log. EP-4 is expected to add `http-client-tls >=0.3 && <0.5`, and `http-client ^>=0.7` only if it is named directly. It also adds `servant-client-core >=0.20.3 && <0.22`, matching servant-client 0.20.3.0's own bound, because `Servant.Client.Generic` (`genericClientHoist`) is not re-exported by servant-client. EP-3 is expected to add `time ^>=1.14`, a GHC boot package and already a dependency of servant-client 0.20.3.0. Both ranges are copied from Baikai's own Cabal files, which declare `http-client-tls >=0.3 && <0.5` and `time ^>=1.14`. EP-6 owns the final bounds review.

**`src/TypeSafe/Wire.hs`, the umbrella module.**
- *Plans:* EP-1, EP-2, EP-3.
- *Owner:* EP-1 creates it, re-exporting `TypeSafe.Wire.Common`.
- *Later plans:* EP-2 adds the re-export of `TypeSafe.Wire.Request`. EP-3 adds `TypeSafe.Wire.Response`, `TypeSafe.Wire.Models` and `TypeSafe.Wire.Error`. Consumers import `TypeSafe.Wire` alone.

**`TypeSafe.Wire.Common` primitives.**
- *Plans:* EP-1 defines; EP-2, EP-3, EP-4 and EP-5 consume.
- *Contents:*
  - `apiSpecVersion :: Text`.
  - `newtype ModelName = ModelName Text` and `newtype QuestionName = QuestionName Text`, each with `deriving stock (Generic, Show)` and `deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)`.
  - The constants `jevLatest` and `jevPreview`.
  - `data Content = ContentText Text | ContentObject Object | ContentArray Array`, with `ToJSON` (including `toEncoding`), `FromJSON` (which rejects numbers, booleans and null), `contentFromValue :: Value -> Maybe Content` and `contentToValue :: Content -> Value`.
  - The constants `requestIdHeader` (`x-typesafe-request-id`), `dangerZoneImagesHeader` (`TypeSafe-Danger-Zone-Images`), `dangerZoneLongContextHeader` (`TypeSafe-Danger-Zone-Long-Context`), `systemOnePath` (`["v1", "systemone"]`), `modelsPath` (`["v1", "models"]`) and `defaultBaseUrl` (`https://api.typesafe.ai`).
- *Nullable positions:* `Content` has no null constructor. Positions where the schema also allows null use `Maybe Content`, with the rule recorded in the Decision Log below.

**Codec conventions shared by EP-2 and EP-3, checked by EP-5.**
- *Both directions:* every wire type has both `ToJSON` (with a hand-written `toEncoding` that agrees with `toJSON`) and `FromJSON`. EP-4's mock server must encode responses, and EP-5 checks decode-after-encode for every schema.
- *Field names:* a field takes the property's name verbatim. Snake-case names become lower camel case (`input_tokens` becomes `inputTokens`, `release_date` becomes `releaseDate`, `data_base64` becomes `dataBase64`). The reserved word `type` becomes `type_` where it is a real field, on `ValidationError`.
- *Tags:* the discriminator `type` on questions and answers is implied by the constructor and is never a field. Each variant record (`NoulQuestion`, `ChoiceAnswer`, and so on) still owns its tag in both directions: its own encoder writes `"type"`, and its own decoder requires it, because each variant schema lists `type` as required. The `Question` and `Answer` sums only dispatch. The constant `type` on `Asset` is implied by the type, written on encode and accepted when absent or equal to `"image"` on decode.
- *Instances and optionality:* every wire type has `deriving stock (Generic, Eq, Show)`. Every deriving clause names its strategy, which is required because `DeriveAnyClass` is on. EP-4 and EP-5 rely on `Eq` and `Show`. `Generic` lets consumers use generic-lens `#label` access without the library depending on lens. A property the document leaves optional is a `Maybe` field. Two non-obvious cases are `HTTPValidationError.detail` and every `Asset` field, including its constant `type`.
- *Field access:* `NoFieldSelectors` is on, so no top-level selector functions are generated. Fields are read with record dot syntax or generic-lens. Library code constructs records and never uses record update syntax on wire types. No module re-enables `FieldSelectors`: record dot syntax also resolves `NamedRoutes` route fields such as `routes.systemOne`, verified on 2026-10-21 with GHC 9.12.4 and servant 0.20.3.0, so `TypeSafe.V1` reads its `Routes` record the same way (see Surprises & Discoveries).
- *Numbers and collections:* token counts and validation-location indices are `Int`, and a non-integral or out-of-range value fails to decode. `SystemOneRequest.assets` is a plain `Map Text Asset`, omitted when empty.
- *Imports:* qualified imports use the postpositive form (`import Data.Map.Strict qualified as Map`).
- *Unknown keys:* unknown additional properties are ignored on decode.
- *Unknown tags:* a `type` tag outside the known set decodes to `QuestionOther tag object` or `AnswerOther tag object`, and re-encodes the original object unchanged.
- *Ownership:* EP-5 owns the table mapping each schema property to its Haskell field, which is the single place this convention is checked.

**Golden fixture files under `test/golden/`.**
- *Plans:* EP-2, EP-3, EP-4, EP-5.
- *Owners:* EP-2 owns `test/golden/baikai-request.json`, R11's request, and its exact-bytes companion `test/golden/baikai-request.bytes`. EP-3 owns `test/golden/baikai-response.json` and the negative variants with `confidence` or `score` removed. EP-4 owns `test/golden/validation-error-422.json`, the 422 body its mock server returns.
- *Consumers:* EP-4 reuses both as the payloads its mock server receives and returns. EP-5 may read them but does not change them.

**`spec/openapi.json` and `scripts/check-spec-drift.sh`.**
- *Owner:* EP-1 vendors the document, normalised with `jq -S .` so that diffs are stable, and writes the drift script.
- *Rule:* no other plan edits the vendored document. A plan that discovers drift records it in this MasterPlan's Surprises & Discoveries and stops for a decision instead of re-vendoring silently.
- *Consumers:* EP-5 reads the document. The `apiSpecVersion` equality test is EP-1's; EP-5 does not duplicate it.

**Test-suite helpers.**
- *`test/Main.hs`:* EP-1 owns it. Each plan registers one tasty group there. EP-5 is the one exception: it moves the loading of `spec/openapi.json` into a shared loader that honours the `TYPESAFE_OPENAPI_SPEC` override, and passes the loaded document to EP-1's version test as well as to its own group.
- *Naming:* test modules end in `Test` (`TypeSafe.Wire.RequestTest`, `TypeSafe.V1Test`, `TypeSafe.Conformance.SchemaTest`), and each exports a `tests` value.
- *`test/TypeSafe/Test/Arbitrary.hs`:* EP-5 owns the QuickCheck `Arbitrary` instances. EP-2 and EP-3 use hand-written values and golden files only, so they never need these instances.
- *`test/TypeSafe/Test/MockServer.hs`:* EP-4 owns the loopback mock server, which is built from `TypeSafe.V1.API` with `servant-server` and `warp`.

**The early producer/consumer check.**
- *Owner:* EP-4.
- *What it proves:* a body sent through `makeMethods` arrives at the loopback server byte-equal to `encodeSystemOneRequest` of the same value. It also proves that a 422 reply surfaces as `FailureResponse` with a body that `parseErrorBody` decodes to `ErrorBodyValidation`.
- *Schedule:* it runs immediately after the `API` type compiles, before any further method variants are added. This is the integration that Baikai's loopback fixture relies on.

**Consumer check against Baikai's bounds.**
- *Owner:* EP-6.
- *What it proves:* a scratch project outside this repository builds the source distribution with R12's dependency bounds as constraints. The check never touches the Baikai checkout.

**ADRs.** EP-1 creates the corpus and records the cross-plan decisions already made:
- the ADR convention itself;
- that the library carries no transport policy (R1, citing Baikai's ADRs above);
- that the wire types mirror the vendored specification, covering the naming convention, both codec directions, lossless numbers, no semantic validation in decoders and surfaced unknown tags;
- that the first release targets the current published document with JSON bodies only, deferring multipart to the follow-up plan.

EP-1 also records which haskell-jitsurei patterns were adopted and which were declined (`docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`). Later plans update those records, or add new ones, when they change these decisions.


## Progress

Not started as of 2026-10-22. All six child plans have been drafted and reviewed, and the review's findings were applied the same day; EP-1 is the only plan that can start. There are no integration gates beyond those owned by EP-4 (the loopback byte-equality check) and EP-6 (the Hackage-only consumer build and upload).


## Surprises & Discoveries

- **The published OpenAPI document has drifted since `docs/initial-spec.md` was written, without a version bump.** Both the published copy, fetched 2026-10-21, and the reference copy in the community SDK (`mori://byteally/typesafe-sdk/packages/typesafe-ai-core`, project-relative path `typesafe-sdk/typesafe-ai-core/spec/openapi.json`, artifact-level URI pending) report `info.version` `0.2.0`. The published copy adds:
  - the schemas `BoxQuestion`, `BoxAnswer`, `BoxCoordinates` and `Asset`;
  - an optional `assets` map on `SystemOneRequest`;
  - `box` entries in both discriminator mappings;
  - a `multipart/form-data` request body;
  - the two `TypeSafe-Danger-Zone-*` header parameters;
  - `minProperties: 1` and `maxProperties: 255` on choice criteria;
  - `minItems: 1` and `maxItems: 10` on score criteria;
  - optional `ctx` and `input` on `ValidationError`;
  - named request and response examples for each question type;
  - a `servers` entry.

  Because the version label did not move, `apiSpecVersion` cannot by itself detect drift, so EP-1's drift script compares content. Evidence:

```text
$ jq -r '.info.version, (.components.schemas|keys|join(","))' openapi.json   # published, 2026-10-21
0.2.0
Answer,Asset,BoxAnswer,BoxCoordinates,BoxQuestion,ChoiceAnswer,ChoiceQuestion,HTTPValidationError,ModelMetadata,ModelMetadataList,NoulAnswer,NoulCriteria,NoulQuestion,Question,ScoreAnswer,ScoreQuestion,SystemOneRequest,SystemOneResponse,Usage,ValidationError
```

- **Not every observed error body is in the specification.** The official TypeScript SDK (local checkout `/Users/shinzui/Keikaku/hub/agents/typesafe-sdk-js`, v0.7.0, `src/errors.ts`) also parses `{"error": "…"}`, `{"error": {"message": …}}` and `{"message": …}`. It reports that 401 replies use the `error` form, and that an unknown model is a 400 with `{"detail": {"error_type": "api_usage_error", "message": "Unknown model: …"}}`. R6 only requires the `detail` forms, but EP-3 should know that the other forms will reach the raw-JSON fallback.


- **Record dot syntax does resolve `NamedRoutes` route fields.** The haskell-jitsurei servant-routes pattern said `HasField` cannot see through a route field's `(:-)` type family, and EP-4, EP-5 and EP-7 had `TypeSafe.V1` re-enable `FieldSelectors` for that reason. A scratch project on GHC 9.12.4 with servant 0.20.3.0, servant-client 0.20.3.0, generic-lens 2.3.0.0 and lens 5.3.6 showed the claim is false: under `NoFieldSelectors` with `OverloadedRecordDot`, record dot, generic-lens labels and selector application all typecheck for `AsClientT IO`, `AsClientT ClientM` and a `RunClient m`-polymorphic record. The pattern document was corrected on 2026-10-22, and the plans now keep `TypeSafe.V1` under `NoFieldSelectors`. Evidence:

```haskell
routesIO :: Routes (AsClientT IO)
routesIO = genericClientHoist run
  where
    run :: ClientM x -> IO x
    run _ = fail "no network in this repro"

listModels :: IO [Int]
listModels = routesIO.models "Bearer test"   -- compiles and runs
```

  The one trap nearby: `genericClientHoist` leaves its source monad to the natural transformation's type, so a stub that ignores its argument needs the signature shown, while a body that applies `runClientM` pins the monad on its own.

## Decision Log

- Decision: Target the OpenAPI document as published on 2026-10-21 and bind every schema in it, including the box and asset schemas. Bind JSON request bodies only, and defer the multipart request body to a separate plan outside this MasterPlan ([docs/plans/7-send-images-with-multipart-system-one-requests.md](../plans/7-send-images-with-multipart-system-one-requests.md)).
  Rationale: R10 requires every schema in the vendored document to be bound, and the drift script must not report the vendored copy as stale on day one. Binding multipart would need `servant-multipart-api` and `servant-multipart-client`, which lie outside R1's dependency list, while Baikai needs no images. The user chose this option when asked.
  Date: 2026-10-21

- Decision: `Content` has three constructors and no null. In positions where the schema allows null, `Maybe Content` is used with one rule per position.
  - **Required-but-nullable slots** are choice-criteria map values: `Nothing` encodes as JSON `null`, because a map entry must have a value, and the specification states that "a choice without a description is interpreted by its name alone".
  - **Optional-and-nullable properties** are every `instructions`, and noul criteria's `true` and `false`: `Nothing` is omitted on encode, and both an absent key and an explicit `null` decode to `Nothing`.
  - **Score criteria items** are not nullable in the document, so score criteria are `NonEmpty Content`.

  Rationale: R7 forbids stringifying, and R3 requires "no description" to stay distinguishable on the wire. R3's phrase "a choice description that is `Nothing` is omitted" cannot be honoured literally inside a JSON map, so this rule resolves that ambiguity.
  Date: 2026-10-21

- Decision: `questions` stays a `Vector (QuestionName, Question)`, as in the specification's sketch, and choice criteria a `Vector (Text, Maybe Content)`. Duplicates are reported by the pure functions `duplicateQuestionNames` and `duplicateChoiceLabels`, not prevented by a smart constructor.
  Rationale: this resolves an open decision in `docs/initial-spec.md`. It matches the surface Baikai's plan was written against, keeps record construction plain, and still satisfies R3's "reported by a pure validation function".
  Date: 2026-10-21

- Decision: the package name is `typesafe-hs` and modules live under `TypeSafe.*`: `TypeSafe.Wire` and its submodules, and `TypeSafe.V1`.
  Rationale: this resolves an open decision. The Nix wiring (`nix/haskell.nix`) and `mori.dhall` already use `typesafe-hs`. The community SDK publishes `typesafe-ai` and `typesafe-ai-core`, so there is no clash on Hackage. EP-6 re-verifies that the name is free before uploading.
  Date: 2026-10-21

- Decision: adopt the haskell-jitsurei conventions that fit a policy-free Hackage client, and record the rest as declined in `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`, which EP-1 creates.
  - *Sources:* `mori://shinzui/haskell-jitsurei/docs/core-standards`, `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`, `mori://shinzui/haskell-jitsurei/docs/core-multiline-strings` and `mori://shinzui/haskell-jitsurei/docs/api-servant-routes`.
  - *Adopted:* the GHC2024 baseline stanza, postpositive qualified imports, explicit deriving strategies with `Generic` on every wire type, strict fields without prefixes, `MultilineStrings` in tests, and a `NamedRoutes` record with the auth header on each route field.
  - *Adopted from the idiom review the same day:* `NoFieldSelectors`, `Int` token counts and location indices, and a plain `Map` for assets.
  - *Declined:*
    - `MultiVerb`, because R1 requires an unmodified `ClientError` and we do not own the server's status set;
    - a custom prelude, and `lens` or `generic-lens` as library dependencies, because of R1's dependency list;
    - generic aeson options, because R3 needs exact bytes;
    - the server-side API patterns, because this library consumes an API rather than serving one.
  - *Left for a separate decision:* a `newtype` for the API token, `NFData` instances, and exposing `Internal` modules.

  Rationale: the user asked for the identified items to be applied to the plans, and haskell-jitsurei is the fleet's convention catalogue. Each declined pattern conflicts with a numbered requirement in `docs/initial-spec.md`.
  Date: 2026-10-21

- Decision: the test framework is `tasty`, with `tasty-hunit`, `tasty-quickcheck` and `tasty-golden` as needed, all in one test suite.
  Rationale: this follows the community SDK, whose conformance approach R10 asks us to copy. One suite keeps `cabal test` a single command.
  Date: 2026-10-21


- Decision: the multipart follow-up, [docs/plans/7-send-images-with-multipart-system-one-requests.md](../plans/7-send-images-with-multipart-system-one-requests.md), is a standalone ExecPlan with no `master_plan` link and no intention. Its prerequisite is that this whole MasterPlan is complete.
  Rationale: the user asked for the missing part to be planned now and implemented later. Registering it as a child would keep this initiative open until it is done. That plan's own Milestone 0 is a design decision the user must confirm, because it may change R1 and R12's dependency scope.
  Date: 2026-10-21
- Decision: `TypeSafe.V1` stays under the package-wide `NoFieldSelectors` and reads its `Routes` record with record dot syntax; no module re-enables `FieldSelectors`.
  Rationale: the exception rested on the haskell-jitsurei claim that record dot cannot see through `NamedRoutes` fields, which the review refuted (see Surprises & Discoveries). Without the exception the package exports no selector functions at all, so `Methods` and `DangerZone` are read like every wire type. EP-1's ADR 0005 specification, EP-4, EP-5, EP-6 and EP-7 were updated to match.
  Date: 2026-10-22

- Decision: every `-Werror=` flag lives in the `package typesafe-hs` stanza of `cabal.project`, never in `typesafe-hs.cabal`. EP-1 sets `-Werror=missing-fields` there and EP-5 adds `-Werror=incomplete-patterns` there.
  Rationale: EP-5 had placed its flag in the test-suite stanza of the Cabal file, which EP-6's `cabal check` acceptance forbids. The `cabal.project` stanza already applies to the test suite, so nothing is lost.
  Date: 2026-10-22

- Decision: test modules carry a `Test` suffix (`TypeSafe.Wire.RequestTest`, `TypeSafe.V1Test`, `TypeSafe.Conformance.SchemaTest`, `TypeSafe.Conformance.OperationsTest`), and a library bound that Baikai also declares is copied from Baikai verbatim, so EP-3's `time` bound is `^>=1.14`.
  Rationale: the review found four different suffixes across the plans and two `time` intervals; one convention each removes the drift before any file exists.
  Date: 2026-10-22

## Outcomes & Retrospective

(To be filled during and after implementation.)

Revision note (2026-10-22): applied the findings of the 2026-10-22 review. `-Werror=` flags are confined to `cabal.project`; `TypeSafe.V1` no longer re-enables `FieldSelectors`, after the record-dot premise was refuted and the haskell-jitsurei pattern corrected; Integration Points now name the owners of `extra-source-files` entries, EP-5's shared document loader and the test-module naming convention; EP-3's `time` bound follows Baikai's. EP-6's Hackage facts and EP-4's servant checkout paths were corrected in the children.
