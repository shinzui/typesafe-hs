---
id: 4
slug: bind-the-system-one-api-with-servant-and-servant-client
title: "Bind the System One API with servant and servant-client"
kind: exec-plan
created_at: 2026-10-21T17:50:12Z
intention: "intention_01m5frxsb3e9et3b9mn8e31r8c"
master_plan: "docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md"
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-10-21T17:50:12Z
---

# Bind the System One API with servant and servant-client

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Once this plan is done, a Haskell program can call TypeSafe's System One API through `typesafe-hs` itself. It needs no hand-written HTTP code. The program builds a `ClientEnv` (servant-client's bundle of connection manager and base URL) with `getClientEnv "https://api.typesafe.ai"`. It then gets a record of methods from `makeMethods clientEnv apiKey` and calls `createSystemOne request` or `listModels`.

Every failure arrives as servant-client's own `ClientError` exception, exactly as servant-client produced it. This library adds no retry, classification, timeout or logging. For an error reply that means `FailureResponse`, which carries the raw status, headers and body. That shape is the one the Mercury `openai` and `claude` Haskell packages use, and it is what requirement R1 in [docs/initial-spec.md](../initial-spec.md) asks for.

The same servant `API` type also describes the server side. This plan uses it to build a loopback mock server: an HTTP server on `127.0.0.1` inside the test suite. The tests prove three things against that server:

- The bytes `makeMethods` puts on the wire equal `encodeSystemOneRequest` of the same value, as R3 requires.
- The `Authorization` header is `Bearer <key>`.
- A 422 reply surfaces as a `FailureResponse` whose body `parseErrorBody` understands.

You can see it working by running the test group `TypeSafe.V1`. With `cabal repl`, you can also point `getClientEnv` at the mock server, or with a real key at the live service.

This is EP-4 of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md). Its Milestone 1 is a declared prerequisite ("EP-4 M1") of [docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md). Keep that milestone's acceptance exactly as stated below.


## Progress

- [ ] Milestone 1 (EP-4 M1): `TypeSafe.V1` exports the `API` type and its endpoint sub-types, compiling in the library. Acceptance: `cabal build lib:typesafe-hs` succeeds with `-Wall` clean, and `cabal repl` shows `:kind! TypeSafe.V1.API` without error.
- [ ] Milestone 2: the loopback producer/consumer check passes. Acceptance: the `TypeSafe.V1` tests prove four things: the request bytes received by the mock server equal `encodeSystemOneRequest`; `Authorization: Bearer <key>` is sent; the golden response round-trips; and a 422 reply surfaces as `FailureResponse` with a body `parseErrorBody` decodes to `ErrorBodyValidation`.
- [ ] Milestone 3: the full `Methods` surface is proven. Acceptance: the danger-zone headers are sent only when requested; `listModels` decodes; `getClientEnv` parses a base URL and rejects a malformed one; `cabal test` passes as a whole.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: `getClientEnv` builds its connection manager from `Network.HTTP.Client.TLS.tlsManagerSettings` unchanged. It sets no response timeout, which differs on purpose from Mercury's `getClientEnv`, where it is `responseTimeoutNone`.
  Rationale: R1 forbids timeout policy beyond what the caller's `Manager` carries. Choosing "no timeout" is a policy, just as choosing thirty seconds would be. Keeping http-client's defaults is the least opinionated choice. A caller who wants a different timeout or proxy behaviour builds its own `ClientEnv` with `Servant.Client.mkClientEnv`, which `makeMethods` accepts. The comment on `getClientEnv` says so.
  Date: 2026-10-21

- Decision: add `http-client-tls` (`>=0.3 && <0.5`, the range Baikai's own Cabal files declare; 0.4.0 is the newest on Hackage as of 2026-10-21) to the library's dependencies. Add `http-client` (`^>=0.7`) only if `TypeSafe.V1` must name an http-client type or settings field directly.
  Rationale: the specification asks for a `getClientEnv :: Text -> IO ClientEnv` convenience that builds a TLS `ClientEnv`. servant-client brings `http-client` but not `http-client-tls`. Both are already in Baikai's build plan through the Mercury `openai` package, whose `openai.cabal` lists `http-client` and `http-client-tls`, so the dependency does not widen what Baikai resolves. R1's list says "plus whatever servant-client itself brings". This is the one deliberate addition, and EP-6 reviews the final bounds.
  Date: 2026-10-21

- Decision: the danger-zone headers have type `Text` at the type level, and `TypeSafe.V1` always sends the literal value `"true"`. Callers choose them with a `DangerZone` record of two `Bool`s, through a second method, `createSystemOneWith`. `createSystemOne` keeps the exact signature the specification sketches.
  Rationale: the OpenAPI document allows only the value `"true"` (`enum: ["true"]`). A dedicated header-value type would need a `ToHttpApiData` instance and so a direct `http-api-data` dependency, which R1's list does not include. A record of `Bool`s keeps call sites readable and makes it impossible to send any other value.
  Date: 2026-10-21

- Decision: the `Methods` record returns only response bodies. It does not expose the `x-typesafe-request-id` response header on success.
  Rationale: the specification's surface sketch has `createSystemOne :: SystemOneRequest -> IO SystemOneResponse`. Baikai's provider makes its own http-client call and reads headers itself. On failure the header is still reachable, because it is kept inside `FailureResponse`. Exposing it on success means wrapping the response type in servant's `Headers`, which would be an additive change for a later release.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

The repository at `/Users/shinzui/Keikaku/bokuno/typesafe-hs` is a single Cabal package named `typesafe-hs`, built inside a Nix development shell. Run every command below through `nix develop -c …` from the repository root, or inside a shell entered with `nix develop` or via direnv. The governing requirements are R1 to R12 in [docs/initial-spec.md](../initial-spec.md). This plan implements:

- **R1:** the servant `API`, `getClientEnv` and `makeMethods`, with no policy;
- **R3:** the byte-equality clause, under which a body sent through `makeMethods` must equal `encodeSystemOneRequest` of the same value;
- **R6:** the consumer side, where the raw response is kept inside `FailureResponse`.

Some terms used throughout:

- **servant:** a Haskell library in which an HTTP API is written as a type. For example, `"v1" :> "models" :> Get '[JSON] ModelMetadataList` means "GET /v1/models returns a JSON `ModelMetadataList`".
- **servant-client:** derives client functions from such a type. `Servant.Client.client (Proxy @API)` yields one function per endpoint, running in the `ClientM` monad. `runClientM action clientEnv` performs the request and returns `Either ClientError a`.
- **servant-server:** derives a WAI `Application`, a web-server handler, from the same type. warp is the web server that runs it; `Network.Wai.Handler.Warp.testWithApplication` runs an application on a free loopback port for the duration of a test.
- **`Header' '[Required, Strict] "Authorization" Text`:** a header that the client must supply (it becomes a plain `Text` argument). The `Optional` form becomes a `Maybe Text` argument that, when `Nothing`, sends no header.
- **`ClientError`:** servant-client's failure type, defined in `Servant.Client.Core.ClientError` and re-exported by `Servant.Client`. In servant-client 0.20 it has these constructors:
  - `FailureResponse (RequestF () (BaseUrl, ByteString)) Response` for a non-2xx reply;
  - `DecodeFailure Text Response`;
  - `UnsupportedContentType MediaType Response`;
  - `InvalidContentTypeHeader Response`;
  - `ConnectionError SomeException`.

  `Response` has the fields `responseStatusCode`, `responseHeaders`, `responseHttpVersion` and `responseBody`; the body is a lazy `ByteString`.
- **The JSON content type in servant:** in servant 0.20.x, `Servant.API.ContentTypes` defines it as `instance {-# OVERLAPPABLE #-} ToJSON a => MimeRender JSON a where mimeRender _ = encode`. That is why a body sent through servant uses the same `toEncoding` as `encodeSystemOneRequest`, and why no plan may define a custom `MimeRender JSON` instance for a wire type. The local servant checkout, located with `mori registry search servant-client`, is at version 0.20.3.0 for servant-client and 0.20.4.0 for servant.

This plan builds on three earlier plans, all of which must be Complete before it starts.

[docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md) provides:
- `typesafe-hs.cabal`, with a common stanza that enables `GHC2024`, `DuplicateRecordFields`, `OverloadedRecordDot` and `OverloadedStrings`;
- the library (`hs-source-dirs: src`) and the single tasty test suite `typesafe-hs-test` (`hs-source-dirs: test`, `main-is: Main.hs`);
- `test/Main.hs`, which assembles the tasty test tree;
- the module `TypeSafe.Wire.Common`, which defines `ModelName`, `QuestionName`, `Content` and these constants:
  - `requestIdHeader` (`x-typesafe-request-id`);
  - `dangerZoneImagesHeader` (`TypeSafe-Danger-Zone-Images`);
  - `dangerZoneLongContextHeader` (`TypeSafe-Danger-Zone-Long-Context`);
  - `systemOnePath`, `modelsPath` and `defaultBaseUrl` (`https://api.typesafe.ai`);
- the umbrella module `TypeSafe.Wire`, which re-exports all the wire modules.

[docs/plans/2-encode-system-one-requests-deterministically.md](2-encode-system-one-requests-deterministically.md) provides:
- the module `TypeSafe.Wire.Request`, with `SystemOneRequest` (fields `model`, `state`, `questions`, `assets`), the `Question` sum type and its variants, `ToJSON` instances with a hand-written `toEncoding`, `FromJSON` instances (after decoding, the order of questions and choice criteria is unspecified), and `encodeSystemOneRequest :: SystemOneRequest -> Data.ByteString.Lazy.ByteString`;
- the golden file `test/golden/baikai-request.json`, the request from R11.

[docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md](3-decode-system-one-responses-model-listings-and-error-bodies.md) provides:
- the module `TypeSafe.Wire.Response`, with `SystemOneResponse` and its answers, both codec directions and `decodeSystemOneResponse`;
- the module `TypeSafe.Wire.Models`, with `ModelMetadataList` (field `models`) and `ModelMetadata` (`name`, `description`, `releaseDate`), both directions;
- the module `TypeSafe.Wire.Error`, with `ErrorBody` (including the constructor `ErrorBodyValidation HTTPValidationError`), `HTTPValidationError`, `ValidationError`, `LocationSegment` and `parseErrorBody :: Data.ByteString.Lazy.ByteString -> ErrorBody`;
- the golden file `test/golden/baikai-response.json`, the response from R11.

This plan assumes those wire types derive `Eq` and `Show`, which their tests require anyway. If a constructor or field name differs from what is written here, use the name the module actually exports and record the difference in Surprises & Discoveries.

The shape to copy is the Mercury client packages:

- `mori://MercuryTechnologies/claude`, project-relative path `src/Claude/V1.hs` (artifact-level URI pending; local checkout `/Users/shinzui/Keikaku/hub/haskell/claude-project/claude`):
  - the `getClientEnv` definition (around lines 92 to 96);
  - `makeMethodsWith`, which applies `Client.hoistClient @API Proxy run (Client.client @API Proxy)` to its header arguments and pattern-matches the resulting `:<|>` tree into record fields, where `run` calls `Client.runClientM` and rethrows `Left` with `Exception.throwIO`;
  - `type API = Header' [Required, Strict] "x-api-key" Text :> Header' [Optional, Strict] "anthropic-version" Text :> … :> "v1" :> (…)`.
- `mori://MercuryTechnologies/openai`, project-relative path `src/OpenAI/V1.hs` (artifact-level URI pending; local checkout `/Users/shinzui/Keikaku/hub/haskell/openai-project/openai`):
  - the same `getClientEnv` (around lines 166 to 177);
  - a `makeMethods` that builds `authorization = "Bearer " <> token` (lines 183 to 197);
  - `type API = Header' [Required, Strict] "Authorization" Text :> … :> "v1" :> (…)`, near line 874.

Our module differs from those in three ways. It has only two endpoints. It has no streaming. And `getClientEnv` keeps http-client's default timeout (see Decision Log).

**ADRs.** EP-1 creates this repository's ADR corpus under `docs/adr/`; run `ls docs/adr` to see it. That corpus includes a record that the library carries no transport policy, and that record is the local ADR relevant here. If this plan's `getClientEnv` decision is not already reflected in it, add a short paragraph to that ADR in the same change. Behind R1 sit two Baikai decisions, which Mori has no artifact-level handles for (artifact-level URIs pending):

- `mori://shinzui/baikai`, project-relative path `docs/adr/0005-what-baikai-deliberately-does-not-do.md`: Baikai never retries.
- `mori://shinzui/baikai`, project-relative path `docs/adr/0011-core-owns-transport-failure-classification.md`: Baikai's core, not a provider dependency, maps transport failures to categories.

Together they explain why `makeMethods` must rethrow `ClientError` unchanged.


## Plan of Work

The work adds one library module, `src/TypeSafe/V1.hs`, and two test modules: `test/TypeSafe/Test/MockServer.hs`, the loopback server, and `test/TypeSafe/V1Spec.hs`, the tests. It edits `typesafe-hs.cabal` to list the new modules and their dependencies, and edits `test/Main.hs` to register the new test group. It touches no wire module. If a wire type turns out to need a change, for example a missing `Eq`, make that change in the owning module under its own plan's conventions, and note it here in Surprises & Discoveries.


### Milestone 1 (EP-4 M1): the API type compiles in the library

Create `src/TypeSafe/V1.hs` and add `TypeSafe.V1` to `exposed-modules`. Add `servant` and `servant-client`, and `http-client-tls` (with `http-client` only if needed), to the library's `build-depends`, with bounds that sit inside R12's list. Define and export the endpoint sub-types first, then `API`:

```haskell
-- | @POST /v1/systemone@, relative to @/v1@. The two optional headers carry
-- the only value the specification allows, @"true"@.
type SystemOneEndpoint =
  "systemone"
    :> Header' '[Optional, Strict] "TypeSafe-Danger-Zone-Images" Text
    :> Header' '[Optional, Strict] "TypeSafe-Danger-Zone-Long-Context" Text
    :> ReqBody '[JSON] SystemOneRequest
    :> Post '[JSON] SystemOneResponse

-- | @GET /v1/models@, relative to @/v1@.
type ModelsEndpoint = "models" :> Get '[JSON] ModelMetadataList

-- | Every operation in the vendored specification, relative to @/v1@.
type Endpoints = SystemOneEndpoint :<|> ModelsEndpoint

type API =
  Header' '[Required, Strict] "Authorization" Text
    :> "v1"
    :> Endpoints
```

Order the export list as `API`, `Endpoints`, `SystemOneEndpoint`, `ModelsEndpoint`, then the items Milestone 3 adds. EP-5 relies on these exact names, `API`, `Endpoints`, `SystemOneEndpoint` and `ModelsEndpoint`, to check that every operation in `spec/openapi.json` is bound. Do not rename them without updating [docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md) and the MasterPlan. The type-level header names must match the constants in `TypeSafe.Wire.Common`; Milestone 3 adds a test asserting that with `GHC.TypeLits.symbolVal`.

In this milestone, also write `Methods`, `getClientEnv` and `makeMethods` in their final form. The milestone's acceptance is only that the module compiles; behaviour is proven in Milestones 2 and 3.

```haskell
-- | Which "danger zone" features a System One request opts into. Each flag
-- that is 'True' sends its header with the value @true@; 'False' sends nothing.
data DangerZone = DangerZone
  { images :: !Bool,
    longContext :: !Bool
  }
  deriving stock (Eq, Show)

-- | Sends neither danger-zone header.
noDangerZone :: DangerZone

data Methods = Methods
  { createSystemOne :: SystemOneRequest -> IO SystemOneResponse,
    createSystemOneWith :: DangerZone -> SystemOneRequest -> IO SystemOneResponse,
    listModels :: IO ModelMetadataList
  }

-- | Parses the base URL (for example 'defaultBaseUrl') and builds a TLS
-- 'ClientEnv' with http-client's default settings. Reads no environment
-- variable of its own and sets no timeout; build your own 'ClientEnv' with
-- 'Servant.Client.mkClientEnv' to choose a different manager.
getClientEnv :: Text -> IO ClientEnv

-- | Runs the API against the given environment with the API key sent as
-- @Authorization: Bearer <key>@. Each method throws servant-client's
-- 'ClientError' unchanged on failure.
makeMethods :: ClientEnv -> Text -> Methods
```

Implement `getClientEnv` as `parseBaseUrl (Text.unpack url)` followed by `TLS.newTlsManagerWith TLS.tlsManagerSettings` and `mkClientEnv`. `parseBaseUrl` throws `InvalidBaseUrlException` in `IO` for a malformed URL; let that propagate.

Implement `makeMethods` the way Mercury's `makeMethodsWith` does. Bind `(systemOne :<|> models) = hoistClient (Proxy @API) run (client (Proxy @API)) ("Bearer " <> key)`, where `run action = runClientM action clientEnv >>= either throwIO pure`. Then:

- `createSystemOneWith zone = systemOne (flag zone.images) (flag zone.longContext)`, with `flag True = Just "true"` and `flag False = Nothing`;
- `createSystemOne = createSystemOneWith noDangerZone`;
- `listModels = models`.

Nothing else wraps, catches or inspects the exception. Re-export `ClientEnv` and `ClientError (..)` from `Servant.Client`, so that consumers can name them without importing servant-client themselves.

```bash
cd /Users/shinzui/Keikaku/bokuno/typesafe-hs
nix develop -c cabal build lib:typesafe-hs
nix develop -c cabal repl lib:typesafe-hs
```

In the REPL, `:kind! TypeSafe.V1.API` prints the expanded type, and `:t TypeSafe.V1.makeMethods` prints `ClientEnv -> Text -> Methods`. Commit at this point, so that EP-5's operation-binding milestone can start; then mark EP-4 M1 in Progress.


### Milestone 2: the loopback producer/consumer check

This is the MasterPlan's early integration check. It runs before any further surface is added, because Baikai's loopback fixture depends on the same property.

Create `test/TypeSafe/Test/MockServer.hs` and add it to the test suite's `other-modules`. Add these to the test suite's `build-depends`: `servant-server`, `warp`, `wai`, `http-types`, `bytestring`, `aeson`, `text`, `tasty`, `tasty-hunit`, and `servant-client` if not already present. The module exposes:

```haskell
-- | What the mock server saw for the most recent request.
data Captured = Captured
  { method :: !ByteString,
    path :: !ByteString,
    headers :: ![Header],
    body :: !Data.ByteString.Lazy.ByteString
  }

-- | How the mock server answers @POST /v1/systemone@.
data Reply
  = ReplySuccess SystemOneResponse
  | ReplyError Status [Header] Data.ByteString.Lazy.ByteString

-- | Runs the API on a free loopback port for the duration of the action.
-- The action receives the port and a way to read the last capture.
withMockServer ::
  IORef Reply -> ModelMetadataList -> (Int -> IO (Maybe Captured) -> IO a) -> IO a
```

Build the server with `Servant.Server.serve (Proxy @API) server`:

- The system-one handler ignores the decoded request; the capture is what the tests inspect. It returns the `ReplySuccess` value, or `throwError` of a `ServerError` built from the `ReplyError` parts, setting `errHTTPCode`, `errReasonPhrase`, `errHeaders` and `errBody`.
- The models handler returns the given `ModelMetadataList`.

Wrap the application in a WAI middleware that captures the raw request before servant parses it. It reads the body fully with `Network.Wai.strictRequestBody`, stores a `Captured` value in an `IORef`, and re-supplies the same chunks to the inner application with `Network.Wai.setRequestBodyChunks`. If the local `wai` lacks `setRequestBodyChunks`, use the older `req { requestBody = … }` field. Run it with `Network.Wai.Handler.Warp.testWithApplication`.

Create `test/TypeSafe/V1Spec.hs`, exporting `tests :: TestTree` named `"TypeSafe.V1"`, and register it in `test/Main.hs` the same way the other groups are registered. Each test builds its environment with `getClientEnv (Text.pack ("http://127.0.0.1:" <> show port))`, which also exercises `getClientEnv`; the TLS manager handles plain HTTP as well. It then uses `makeMethods env "test-key"`. The fixtures are loaded from the golden files rather than rebuilt by hand, so this plan does not depend on EP-2's or EP-3's test internals:

- the request value is `eitherDecodeFileStrict "test/golden/baikai-request.json" :: IO (Either String SystemOneRequest)`;
- the response value is decoded the same way from `test/golden/baikai-response.json`.

The milestone's tests are:

1. **Request bytes.** Call `createSystemOne request`. Assert that the captured method is `POST` and the path is `/v1/systemone`. Assert that the captured body is byte-equal to `encodeSystemOneRequest request`; compare `ByteString`s, not decoded values. Assert that the captured `Content-Type` starts with `application/json`.
2. **Authorization.** In the same exchange, the captured `Authorization` header equals `Bearer test-key`.
3. **Response round trip.** With `ReplySuccess response`, the value returned by `createSystemOne` equals `response`.
4. **422 surfaces unchanged.** Set `ReplyError status422 [("Content-Type", "application/json"), ("x-typesafe-request-id", "req_test")] validationBody`. Use the body from the specification's 422 example shape:

```json
{"detail": [{"loc": ["body", "questions", "urgency", "score", "criteria"], "msg": "Field required", "type": "missing"}]}
```

   Store it as `test/golden/validation-error-422.json`, which this plan owns. Catch the exception with `try @ClientError` and pattern-match `FailureResponse _ response`. Assert that `responseStatusCode response` is 422; that `responseHeaders` contains `x-typesafe-request-id: req_test` (look the name up with `requestIdHeader`); and that `parseErrorBody (responseBody response)` is an `ErrorBodyValidation` value whose single entry has `msg` equal to `"Field required"`.


### Milestone 3: the remaining surface

Add tests to `test/TypeSafe/V1Spec.hs`:

- `createSystemOneWith (DangerZone {images = True, longContext = False}) request` sends the header `TypeSafe-Danger-Zone-Images: true` and no long-context header.
- `createSystemOne` sends neither danger-zone header.
- `symbolVal` of each type-level header name equals the matching `TypeSafe.Wire.Common` constant. Compare case-insensitively, since HTTP header names are case-insensitive; prefer exact equality if the constants use the same spelling.
- `listModels` returns the `ModelMetadataList` given to the mock server. Build it in the test from one `ModelMetadata` with `name = "jev-latest"`, `description = "Test model"` and `releaseDate = "2026-09-15"`, or decode the specification's example.
- `getClientEnv "https://api.typesafe.ai"` yields a `ClientEnv` whose `baseUrl` is `BaseUrl Https "api.typesafe.ai" 443 ""`. This makes no network call.
- `getClientEnv "not a url"` throws; check with `try @SomeException`.
- A server reply whose body is not a valid `SystemOneResponse` surfaces as `DecodeFailure`, for example `{"model": "m", "answers": {}}` with status 200, where `usage` is missing. This proves no layer converts or hides decode errors. Implement it by adding `ReplyRaw Status [Header] LazyByteString` to `Reply`; it is served through a raw WAI response path in the middleware, or with servant's `Raw` style if simpler. Note the chosen approach in Surprises & Discoveries.

Then run the whole suite.


## Concrete Steps

All commands run from `/Users/shinzui/Keikaku/bokuno/typesafe-hs`.

Before starting, confirm the prerequisites are in the tree:

```bash
ls src/TypeSafe/Wire/Request.hs src/TypeSafe/Wire/Response.hs src/TypeSafe/Wire/Models.hs src/TypeSafe/Wire/Error.hs test/golden/baikai-request.json test/golden/baikai-response.json
nix develop -c cabal build all
```

All six files must exist and the build must succeed. If any is missing, EP-2 or EP-3 is not complete; stop and report the gap in the MasterPlan instead of stubbing it.

Milestone 1:

```bash
nix develop -c cabal build lib:typesafe-hs
```

Expected: the build ends with no warnings from `TypeSafe.V1`.

Milestones 2 and 3:

```bash
nix develop -c cabal test typesafe-hs-test --test-options='--pattern TypeSafe.V1'
nix develop -c cabal test
```

Expected tail of the focused run once Milestone 3 is done. The test names are illustrative; keep them descriptive.

```text
TypeSafe.V1
  sends the bytes encodeSystemOneRequest produces:  OK
  sends Authorization: Bearer <key>:                 OK
  returns the decoded response:                      OK
  surfaces a 422 as an unchanged FailureResponse:    OK
  sends danger-zone headers only when requested:     OK
  header names match the Common constants:           OK
  listModels decodes the model list:                 OK
  getClientEnv parses the default base URL:          OK
  getClientEnv rejects a malformed URL:              OK
  a malformed success body is a DecodeFailure:       OK

All 10 tests passed
```

Format before committing with `nix fmt`, or let the pre-commit hook run. Commit at each milestone with a Conventional Commits message and all three trailers:

```text
feat(v1): bind the System One API with servant-client

Add TypeSafe.V1 with the API type, Methods, getClientEnv and makeMethods.

MasterPlan: docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ExecPlan: docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md
Intention: intention_01m5frxsb3e9et3b9mn8e31r8c
```


## Validation and Acceptance

**Required acceptance.** This plan is accepted when `nix develop -c cabal test` passes and the `TypeSafe.V1` group shows each of the following, observed against a real HTTP server on loopback:

- the request body that `makeMethods` sends is byte-for-byte `encodeSystemOneRequest` of the same value (R3);
- the key travels as `Authorization: Bearer <key>`;
- a 422 reply reaches the caller as servant-client's `FailureResponse`, with status, headers including `x-typesafe-request-id`, and body intact, and that body parses with `parseErrorBody` (R1, R6);
- a malformed success body reaches the caller as `DecodeFailure`, not as a library-specific error (R1);
- the danger-zone headers appear only when requested;
- `listModels` decodes (R9's binding).

EP-4 M1 is accepted separately, as soon as `cabal build lib:typesafe-hs` succeeds with the exported names listed in Milestone 1.

To show that the byte-equality test has teeth, temporarily change the test to compare against `Data.Aeson.encode (toJSON request)`. That goes through an intermediate `Value`, and aeson sorts the keys of a `Value` object, so with the golden request it should fail: its `questions` order (`urgent`, `category`, `severity`) is not alphabetical. If it passes, the request decoded from the golden file may already be in sorted order, because decoding does not preserve key order (see EP-2). In that case, build the request value in the test with an explicitly non-alphabetical `questions` vector, such as `[("urgent", …), ("category", …)]`, so that the test distinguishes the two paths. Revert the temporary change afterwards.

**Optional manual check, not required.** With a real key in your shell, in `nix develop -c cabal repl lib:typesafe-hs`:

```haskell
env <- getClientEnv defaultBaseUrl
let m = makeMethods env "<your key>"
m.listModels
```

This should print a `ModelMetadataList` that includes `jev-latest`. Reading the key from `TYPESAFE_API_KEY` is done by you in the REPL, never by the library.


## Idempotence and Recovery

Every step is additive: one new library module, two new test modules, one new golden file, and edits to the module and dependency lists. Rebuilding and re-running tests is always safe. The mock server binds an ephemeral loopback port chosen by warp, so tests can run concurrently and repeatedly without port clashes.

If the solver cannot satisfy `servant-server` or `warp` alongside R12's bounds on GHC 9.12.4, run `nix develop -c cabal build all --dry-run` and record the conflict in Surprises & Discoveries. Test-only dependencies do not constrain consumers, so widening a test bound is acceptable. Widening a library bound beyond R12 is not, and needs a MasterPlan decision. To roll back, revert the commits for this plan; no other plan's modules are changed.


## Interfaces and Dependencies

**Prerequisites.** All of [docs/plans/2-encode-system-one-requests-deterministically.md](2-encode-system-one-requests-deterministically.md) and [docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md](3-decode-system-one-responses-model-listings-and-error-bodies.md) must be Complete. [docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md) is Complete transitively. The names this plan consumes are listed in Context and Orientation.

**Produces.** The module `TypeSafe.V1`, exporting:

- `API`, `Endpoints`, `SystemOneEndpoint` and `ModelsEndpoint`. These are EP-4 M1's output, and [docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md) consumes them.
- `Methods (..)`, with fields `createSystemOne`, `createSystemOneWith` and `listModels`.
- `DangerZone (..)`, with fields `images` and `longContext`, and `noDangerZone`.
- `getClientEnv :: Text -> IO ClientEnv` and `makeMethods :: ClientEnv -> Text -> Methods`.
- The re-exports `ClientEnv` and `ClientError (..)`.

It also produces the test-only module `test/TypeSafe/Test/MockServer.hs` (`withMockServer`, `Captured`, `Reply`), which other test code may reuse, and the golden file `test/golden/validation-error-422.json`.

**Library dependencies added here:** `servant` and `servant-client`, compatible with R12's `servant-client ^>=0.20`, and `http-client-tls >=0.3 && <0.5`; `http-client ^>=0.7` only if needed (see Decision Log).

**Test-suite dependencies added here:** `servant-server ^>=0.20`, `warp ^>=3.4`, `wai ^>=3.2`, `http-types ^>=0.12`, plus whatever of `aeson`, `bytestring`, `text`, `tasty`, `tasty-hunit` and `servant-client` the suite does not already list. EP-6 reviews all bounds before release.

**Forbidden in `TypeSafe.V1` (R1):**
- any retry;
- any `catch` that changes or classifies a `ClientError`;
- any timeout setting;
- any `System.Environment` lookup;
- any logging hook;
- any custom `MimeRender` or `MimeUnrender` instance for a wire type, since the byte-equality guarantee depends on servant's stock JSON instance calling aeson's `encode`.
