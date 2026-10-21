---
id: 5
slug: prove-conformance-with-the-vendored-openapi-document
title: "Prove conformance with the vendored OpenAPI document"
kind: exec-plan
created_at: 2026-10-21T17:50:12Z
intention: "intention_01m5frxsb3e9et3b9mn8e31r8c"
master_plan: "docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md"
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
---

# Prove conformance with the vendored OpenAPI document

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

`typesafe-hs` is a Haskell client for TypeSafe's System One API. Its Haskell types and JSON codecs are meant to mirror the API's official OpenAPI document, a JSON description of every endpoint, request body and response body. A copy of that document is checked in at `spec/openapi.json`. Today that mirroring is only a claim. Someone reading the code has to compare it with the document by eye, and nothing notices when TypeSafe changes the document.

After this plan, `cabal test` proves the mirror mechanically. The test suite reads `spec/openapi.json` and checks:

- every operation and every schema in it is bound to Haskell code;
- every property of every schema is emitted by the encoder;
- required properties are required by the decoder, and optional ones are not;
- the `type` tags of questions and answers match the Haskell constructors one for one;
- every example in the document decodes.

A newer copy of the document can be checked without replacing the vendored one by setting `TYPESAFE_OPENAPI_SPEC=/path/to/openapi.json`. Each failure then names the endpoint, schema, property, keyword or content type the bindings do not cover. If the document starts using a JSON Schema keyword or an OpenAPI feature the suite does not understand, the suite fails. It never silently passes.

This is requirement R10 of [docs/initial-spec.md](../initial-spec.md). It is child plan EP-5 of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md).


## Progress

- [ ] Milestone 1: schema reader, validator and audits of the document's own vocabulary. The conformance group passes against the vendored document. The audit reports an injected unknown keyword (`pattern`) and an unlisted content type, and this is checked both by permanent meta-tests and by a manual run against a mutated copy.
- [ ] Milestone 2: `Arbitrary` generators and per-schema codec checks for every schema. These cover validation of encoded values, `toEncoding`/`toJSON` agreement, round trips, emitted properties, required/optional removal and the property-to-field table.
- [ ] Milestone 3: discriminator, unknown-tag, example and constant checks. Constructors match both discriminator mappings, including `box`. Property-level and operation-level examples validate, decode and re-encode. The base URL and paths constants match the document.
- [ ] Milestone 4: operation binding, which requires EP-4 M1. Every `(method, path)` in the document is produced by the servant client of `TypeSafe.V1.API`. Each request carries the declared bearer security and header parameters with the `application/json` content type, and each canned example response decodes.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: round trips compare encoded JSON values for every binding. Exact `Eq` comparison is used only for bindings with no order-carrying fields.
  Rationale: `questions` and choice criteria are ordered `Vector`s of pairs on the Haskell side but JSON objects on the wire. Decoding cannot recover their order: aeson's `KeyMap` iterates in key order. `docs/initial-spec.md` says decoded order is unspecified. Comparing `toJSON` values is order-insensitive for objects, so it checks content without asserting an order the wire cannot carry.
  Date: 2026-10-21

- Decision: the property-to-field table is a list of getters written with record dot syntax (`\r -> r.confidence`). Each getter returns the wire value it expects that property to have. The table is checked against the document's property lists and against the encoder's output.
  Rationale: a getter only compiles if the field exists with that exact name, so R2's "every property a field with its plain name" becomes a compile-time fact. The runtime comparison then proves the field is the one the encoder writes to that property. This file is the single place the naming convention from the MasterPlan is checked: `snake_case` properties become `lowerCamelCase` fields, `type` becomes `type_`, and discriminator tags are implied by constructors. The getters keep working under the project-wide `NoFieldSelectors`: record dot syntax is solved through `HasField`, which does not need selector functions.
  Date: 2026-10-21

- Decision: operations are bound by running the servant client of `TypeSafe.V1.API` in a test-only capturing monad (a `RunClient` instance that records each `Request` and replies with a canned response). The client record is derived with `genericClient @Routes @Capture`. Servant's `safeLink` was considered and not used.
  Rationale: `safeLink` yields only a path. The capturing client yields the HTTP method, path, headers, request content type and response decoding from the same code path `makeMethods` uses, without any network, so security and header parameters can be checked too.
  Date: 2026-10-21

- Decision: the keyword and OpenAPI-field audits are pure functions with their own meta-tests that feed them an in-memory mutated document. The manual run against a mutated file is kept as acceptance evidence.
  Rationale: R10 requires an unknown keyword to cause a test failure. A permanent meta-test keeps that guarantee from regressing, for example if someone widens the supported list carelessly.
  Date: 2026-10-21

- Decision: the `multipart/form-data` request body of `POST /v1/systemone` is the only entry in an explicit exclusion list in the test code. Any other content type other than `application/json` fails the suite.
  Rationale: the MasterPlan defers multipart upload to [docs/plans/7-send-images-with-multipart-system-one-requests.md](7-send-images-with-multipart-system-one-requests.md). Listing it keeps the exclusion visible and lets plan 7 delete the entry when it binds multipart.
  Date: 2026-10-21

- Decision: follow the MasterPlan's alignment with haskell-jitsurei (`mori://shinzui/haskell-jitsurei`) in this plan's test code and expectations.
  - **Operation binding.** It takes the client record from `genericClient @Routes @Capture` and reads each route with selector application (`V1.systemOne client`), never by destructuring `:<|>`. EP-4 now defines the API as a `NamedRoutes` record and exports `API`, `Routes (..)`, `SystemOneEndpoint` and `ModelsEndpoint`.
  - **Integers.** Token counts and `LocationIndex` are `Int`, and the generators stay within `Int`.
  - **Assets.** `SystemOneRequest.assets` is a `Map Text Asset` that is omitted when empty. The generators produce either an empty map or one with at least one entry.
  - **Code style.** Test modules use explicit deriving strategies and postpositive qualified imports. Inline JSON fixtures may use `MultilineStrings`, which EP-1 enables in the test-suite stanza.
  - **`Capture`.** Under `NoFieldSelectors` a record field generates no selector function, so `Capture` is a positional newtype with an explicitly written `runCapture`.

  Rationale: the change set records jitsurei's core standards (`mori://shinzui/haskell-jitsurei/docs/core-standards`), record patterns (`mori://shinzui/haskell-jitsurei/docs/core-record-patterns`) and servant routes pattern (`mori://shinzui/haskell-jitsurei/docs/api-servant-routes`). This suite is where the MasterPlan's codec and binding conventions are checked, so it must check the conventions as revised. Selector application is used for routes because record dot syntax cannot see through a `NamedRoutes` field's `(:-)` type family (jitsurei's "OverloadedRecordDot Does Not Work on Route Fields"). `TypeSafe.V1` re-enables `FieldSelectors` for that reason.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

**Repository.** This repository (`mori://shinzui/typesafe-hs`) holds one Cabal package, `typesafe-hs`, built with GHC 9.12.4 from the Nix development shell. Enter the shell with `nix develop`, or let `direnv` load it through `.envrc`, and run every command below from the repository root `/Users/shinzui/Keikaku/bokuno/typesafe-hs`.

**OpenAPI and JSON Schema.** An "OpenAPI document" is a JSON file describing an HTTP API. `paths` lists the operations: each path, under it each HTTP method, and for each operation its parameters, request body, responses and security requirement. `components.schemas` holds named "schemas". A schema is a JSON Schema object such as `{"type": "object", "properties": {...}, "required": [...]}` that says which JSON values are allowed. The words inside a schema (`type`, `properties`, `required`, `anyOf` and so on) are "keywords". A "discriminator" is the OpenAPI annotation saying that a `oneOf` union is told apart by one property. Here it is the `type` property of a question or answer, and `discriminator.mapping` lists each allowed tag and its schema.

**The vendored document.** `spec/openapi.json` is vendored by EP-1, normalised with `jq -S .`. It is the document published at https://api.typesafe.ai/openapi.json on 2026-10-21, with `info.version` `0.2.0` and OpenAPI 3.1.0. Its root keys are `components`, `info`, `openapi`, `paths` and `servers`, and `servers` is `[{"url": "https://api.typesafe.ai"}]`.

It has two operations:

- **`GET /v1/models`:**
  - security `[{"HTTPBearer": []}]`;
  - no parameters;
  - responses `200` (`application/json`, schema `ModelMetadataList`) and `422` (`application/json`).
- **`POST /v1/systemone`:**
  - security `[{"HTTPBearer": []}]`;
  - two optional header parameters, `TypeSafe-Danger-Zone-Images` and `TypeSafe-Danger-Zone-Long-Context`, each with schema `{"type": "string", "enum": ["true"]}`;
  - a request body offered as `application/json` (schema `SystemOneRequest`, with named `examples` `box`, `choice`, `noul` and `score`) and as `multipart/form-data`;
  - responses `200` (`application/json`, schema `SystemOneResponse`, named `examples` `box`, `choice`, `noul` and `score`) and `422` (`application/json`, schema `HTTPValidationError`, no examples).

`components.securitySchemes.HTTPBearer` is `{"type": "http", "scheme": "bearer"}`.

**Schemas.** There are 20 schemas under `components.schemas`:

```text
Answer Asset BoxAnswer BoxCoordinates BoxQuestion ChoiceAnswer ChoiceQuestion
HTTPValidationError ModelMetadata ModelMetadataList NoulAnswer NoulCriteria
NoulQuestion Question ScoreAnswer ScoreQuestion SystemOneRequest
SystemOneResponse Usage ValidationError
```

Their required properties are:

```text
Asset: (none)                      BoxAnswer: type, box, confidence
BoxCoordinates: top, bottom, left, right
BoxQuestion: type                  ChoiceAnswer: type, choice, confidence, probabilities
ChoiceQuestion: type, criteria     HTTPValidationError: (none)
ModelMetadata: name, description, release_date
ModelMetadataList: models          NoulAnswer: type, noul
NoulCriteria: (none)               NoulQuestion: type
ScoreAnswer: type, score, confidence, legend, probabilities
ScoreQuestion: type, criteria      SystemOneRequest: model, state, questions
SystemOneResponse: model, answers, usage
Usage: input_tokens, output_tokens ValidationError: loc, msg, type
```

Optional properties are `Asset.{data_base64, format, part, type}`, `instructions` on every question, `NoulQuestion.criteria`, `NoulCriteria.{true, false}`, `SystemOneRequest.assets`, `HTTPValidationError.detail` and `ValidationError.{input, ctx}`. `Question` and `Answer` are `oneOf` unions whose discriminator mappings both contain `box`, `choice`, `noul` and `score`.

**Keywords.** These are the JSON Schema keywords used anywhere under `components.schemas` (computed with jq over `properties`, `additionalProperties`, `items`, `anyOf` and `oneOf`):

```text
$ref additionalProperties anyOf const description discriminator enum examples
items maxItems maxProperties minItems minProperties oneOf properties required
title type x-accepts
```

The operation-level schemas additionally use `contentMediaType` and `contentSchema`, inside the multipart body. Note the value forms: `additionalProperties: true` is a boolean, `items: {}` is an empty schema, `enum` appears on `Asset.format` (`png`, `jpg`, `jpeg`) and on the header parameter schemas, and `x-accepts` is a vendor annotation string. The document is read with `jq` because it is plain JSON:

```bash
jq -r '.components.schemas | keys[]' spec/openapi.json
```

**Haskell surface from the hard dependencies.** These names come from [docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md), [docs/plans/2-encode-system-one-requests-deterministically.md](2-encode-system-one-requests-deterministically.md), [docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md](3-decode-system-one-responses-model-listings-and-error-bodies.md) and [docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md). Everything is re-exported by the umbrella module `TypeSafe.Wire` (file `src/TypeSafe/Wire.hs`); the servant binding is in `TypeSafe.V1`. Before writing a test, read those modules to confirm exact constructor names, because the plans fix the conventions while the source fixes the spelling.

- **From EP-1, `TypeSafe.Wire.Common`:**
  - `apiSpecVersion`;
  - the newtypes `ModelName` and `QuestionName` over `Text`;
  - `data Content = ContentText Text | ContentObject Object | ContentArray Array`;
  - `contentFromValue` and `contentToValue`;
  - `jevLatest` and `jevPreview`;
  - the constants `requestIdHeader`, `dangerZoneImagesHeader`, `dangerZoneLongContextHeader`, `systemOnePath` (`["v1", "systemone"]`), `modelsPath` (`["v1", "models"]`) and `defaultBaseUrl` (`https://api.typesafe.ai`).

  EP-1 also creates `typesafe-hs.cabal`, with one `test-suite typesafe-hs-test` (tasty, `hs-source-dirs: test`, `main-is: Main.hs`) and `test/Main.hs`, which owns the tasty tree in which each plan registers one group. It also provides the `apiSpecVersion` equality test, which this plan does not duplicate, and `scripts/check-spec-drift.sh`.
- **From EP-2, `TypeSafe.Wire.Request`:**
  - `SystemOneRequest { model, state, questions :: Vector (QuestionName, Question), assets :: Map Text Asset }`, where `assets` is encoded only when non-empty, and an absent key decodes to `Map.empty`;
  - the union `Question`, with one constructor each for noul, choice, score and box, plus `QuestionOther Text Object`;
  - the records `NoulQuestion { instructions, criteria }`, `NoulCriteria { true, false }`, `ChoiceQuestion { instructions, criteria :: Vector (Text, Maybe Content) }`, `ScoreQuestion { instructions, criteria :: NonEmpty Content }`, `BoxQuestion { instructions }` and `Asset { dataBase64, format, part }`;
  - `encodeSystemOneRequest`, `duplicateQuestionNames` and `duplicateChoiceLabels`.
- **From EP-3, `TypeSafe.Wire.Response`, `TypeSafe.Wire.Models` and `TypeSafe.Wire.Error`:**
  - `SystemOneResponse { model, answers, usage }`;
  - the union `Answer`, with one constructor each for noul, choice, score and box, plus `AnswerOther Text Object`;
  - `NoulAnswer { noul }`, `ChoiceAnswer { choice, confidence, probabilities }`, `ScoreAnswer { score, confidence, legend, probabilities }`, `BoxAnswer { box, confidence }` and `BoxCoordinates { top, bottom, left, right }`;
  - `Usage { inputTokens, outputTokens }`;
  - `ModelMetadataList { models }` and `ModelMetadata { name, description, releaseDate }`;
  - `HTTPValidationError { detail }`, `ValidationError { loc, msg, type_, input, ctx }` and `LocationSegment` (`LocationField Text | LocationIndex Int`);
  - `ErrorBody` and `parseErrorBody`.

  Every probability, confidence and score is a `Scientific`. Token counts are `Int`: the decoder rejects a non-integral number or one that does not fit an `Int`.
- **From EP-4, `TypeSafe.V1`:** the servant API, defined as a `NamedRoutes` record (servant's way of writing an API as a record with one field per route, instead of a positional `:<|>` chain).

  ```haskell
  data Routes mode = Routes
    { systemOne :: mode :- SystemOneEndpoint,
      models :: mode :- ModelsEndpoint
    }
    deriving stock (Generic)

  type API = NamedRoutes Routes
  ```

  `SystemOneEndpoint` and `ModelsEndpoint` are type synonyms for the two endpoints. Each begins with the required `Authorization` header, and `SystemOneEndpoint` also carries the two optional danger-zone headers.

  `TypeSafe.V1` also exports `Methods`, `getClientEnv` and `makeMethods`. It enables `FieldSelectors` with a module pragma, so the route fields `systemOne` and `models` exist as selector functions.

  EP-4's Milestone 1 ("EP-4 M1") is the point at which `TypeSafe.V1` exports `API`, `Routes (..)`, `SystemOneEndpoint` and `ModelsEndpoint`, compiling in the library. Only Milestone 4 here needs it.

**Codec conventions.** These come from the MasterPlan's Integration Points and are what this suite enforces:

- Every wire type has both `ToJSON`, with a hand-written `toEncoding` that agrees with `toJSON`, and `FromJSON`.
- Fields take the property name verbatim, with `snake_case` becoming `lowerCamelCase` and `type` becoming `type_` on `ValidationError`.
- The discriminator `type` is implied by the constructor. Each variant record also encodes its own `"type"` tag, and its decoder requires that tag: a bound schema such as `NoulQuestion` lists `type` as required, so removing it must fail decoding.
- `Asset`'s constant `type` is written on encode and accepted when absent or `"image"`.
- Unknown properties are ignored on decode.
- An unknown `type` tag decodes to `QuestionOther`/`AnswerOther` and re-encodes the original object unchanged.
- Nullable-and-optional properties (`instructions`, noul `true`/`false`) omit `Nothing` and decode `null` or absent to `Nothing`.
- Choice-criteria values encode `Nothing` as `null`.
- `SystemOneRequest.assets` is omitted when the map is empty.
- Every wire type has `deriving stock (Generic, Eq, Show)`, or, for the newtypes, `deriving stock (Generic, Show)` with the remaining instances derived `newtype`.
- **`NoFieldSelectors`.** The project's common stanza turns on `NoFieldSelectors`, so record fields do not become top-level functions. Read a wire type's fields with record dot syntax (`r.confidence`), not with selector application. The one exception is the route fields of `TypeSafe.V1.Routes`, described above.

**Code style for the test modules.** Follow the project's haskell-jitsurei baseline (`mori://shinzui/haskell-jitsurei/docs/core-standards`), which EP-1 sets in the common stanza:

- **Imports.** Write qualified imports in postpositive form, for example `import Data.Aeson.KeyMap qualified as KeyMap`, never `import qualified`.
- **Deriving.** Every deriving clause names its strategy (`deriving stock`, `deriving newtype`). `DeriveAnyClass` is on project-wide, and a clause without a strategy can silently pick the wrong one.
- **Inline JSON.** Long inline fixtures may use `MultilineStrings` (`mori://shinzui/haskell-jitsurei/docs/core-multiline-strings`), which EP-1 enables in the test-suite stanza only.

**Reference implementation.** The community SDK at `mori://byteally/typesafe-sdk/packages/typesafe-ai-core` already has a conformance suite in this style; artifact-level URIs are pending, so files are named by project-relative path. Run `mori registry show byteally/typesafe-sdk --full` to find the checkout; on this machine it is under `/Users/shinzui/Keikaku/hub/haskell/typesafe-sdk-project`. Read these files before starting:

- `typesafe-sdk/typesafe-ai-core/test/TypeSafe/JsonSchema.hs` has the document readers and a validator for a smaller keyword set.
- `typesafe-sdk/typesafe-ai-core/test/TypeSafe/ConformanceSpec.hs` has an existential `Binding` table and per-schema QuickCheck checks.
- `typesafe-sdk/typesafe-ai-core/test/TypeSafe/ArbitraryInstances.hs` has generators.
- `typesafe-sdk/typesafe-ai-core/test/Main.hs` has the `TYPESAFE_OPENAPI_SPEC` override.

Adapt them; do not depend on that package. It differs in ways that matter here:

- its numbers are `Double`;
- its questions are a `Map`;
- it predates the box and asset schemas;
- its validator lacks `enum`, `maxItems`, `maxProperties` and `x-accepts`;
- it only audits keywords under `components.schemas`, not operation-level schemas or OpenAPI fields.

**ADRs.** No ADR existed in this repository when this plan was written. EP-1 creates `docs/adr/` and records that the wire types mirror the vendored specification and that the first release targets JSON bodies only. Run `ls docs/adr` and read those two records before starting. Treat them as authoritative where they differ from this summary, and update them if this plan changes a convention.


## Plan of Work

All new code is test code under `test/`, compiled only into `typesafe-hs-test`. The library gains nothing. The work is four milestones, each adding one group of tests under a single tasty group named `OpenAPI conformance` that this plan registers in `test/Main.hs`.

The suite needs the parsed document. If EP-1's `test/Main.hs` already loads `spec/openapi.json` for its version test, extend that loading. Otherwise add it. Either way, read the path from the `TYPESAFE_OPENAPI_SPEC` environment variable when it is set, defaulting to `spec/openapi.json`, and pass the same loaded `Spec` to EP-1's version test and to `Conformance.tests`, so that an override checks everything against one document. The override is test-only; the library never reads the environment. Confirm that `spec/openapi.json` is listed in `extra-source-files` in `typesafe-hs.cabal`, so that the test suite also runs from a source distribution (EP-6 relies on this), and add it there if EP-1 did not.


### Milestone 1: the document reader, the validator, and the vocabulary audits

This milestone needs only EP-1's artifacts. The MasterPlan still starts this plan only after EP-2 and EP-3 are Complete.

Create `test/TypeSafe/Conformance/JsonSchema.hs`, adapting the community SDK's `TypeSafe.JsonSchema`. It exports:

- `Spec`, a newtype over `Value`;
- `loadSpec :: FilePath -> IO Spec`;
- `specFromValue :: Value -> Spec`, for meta-tests;
- `specVersion`;
- `specOperations :: Spec -> [(Text, Text)]`, giving upper-case method and path;
- `specSchemaNames`;
- `lookupSchema`, `schemaRef`, `objectProperties`, `requiredProperties` and `discriminatorTags`;
- `propertyExamples`, the first `examples` entry of each property;
- `operationExamples :: Spec -> [(Text, Text, Text, Text, Value)]`, giving method, path, `"request"` or the response status, example name and example value, for every `application/json` media object;
- `operationContentTypes :: Spec -> [(Text, Text, Text, Text)]`, giving method, path, `"request"` or the status, and content type;
- `operationParameters`, giving method, path, and the name, location and schema of each parameter;
- `operationSecurity`;
- `securitySchemes`;
- `serverUrls`;
- `unsupportedKeywords :: Spec -> [Text]`;
- `unsupportedOpenApiFields :: Spec -> [Text]`;
- `supportedKeywords`;
- `validate :: Spec -> Value -> Value -> [String]`.

`validate` returns one message per problem, each prefixed with a JSON path; an empty list means valid.

The validator handles exactly these keywords:

- **Assertions:** `$ref` (resolved only within `#/components/schemas/`), `type` (with `integer` meaning `Scientific.isInteger`), `const`, `enum`, `properties`, `required`, `additionalProperties` (boolean or schema), `items` (including the empty schema `{}`), `minItems`, `maxItems`, `minProperties`, `maxProperties`, `anyOf` and `oneOf`.
- **Annotations, which never reject a value:** `title`, `description`, `examples`, `default`, `discriminator`, `x-accepts`, `contentMediaType` and `contentSchema`. JSON Schema 2020-12 defines the last two as annotations.

Any other keyword produces the message `unsupported JSON Schema keyword "<k>"`. `unsupportedKeywords` walks every schema position in the document and returns each keyword not in `supportedKeywords`. The schema positions are:

- each entry of `components.schemas` and, recursively, its `properties` values, object-valued `additionalProperties`, object-valued `items`, and `anyOf`/`oneOf` alternatives;
- each `parameters[].schema`;
- each `requestBody.content.*.schema`, including the multipart one, whose `properties.request` uses `contentMediaType` and `contentSchema`;
- each `responses.*.content.*.schema`.

`unsupportedOpenApiFields` does the same job for OpenAPI structure, so that a new feature such as callbacks, cookies or a new parameter location cannot pass unnoticed. It checks each object's keys against a fixed allow-list:

```text
root:           openapi, info, paths, components, servers
components:     schemas, securitySchemes
operation:      summary, description, operationId, parameters, requestBody, responses, security
parameter:      name, in (value must be "header"), description, schema, example, required
requestBody:    content, required, description
media type:     schema, examples, encoding
response:       description, content
```

Under `paths`, each path item may contain only HTTP methods, and each operation's `security` may name only schemes defined in `components.securitySchemes`. The function reports offending fields as dotted paths, for example `paths./v1/systemone.post.callbacks`.

Create `test/TypeSafe/Conformance/Spec.hs`, exporting `tests :: Spec -> TestTree`. For this milestone it contains:

- **"the schema validator understands every keyword in use":** `unsupportedKeywords spec @?= []`.
- **"every OpenAPI field in use is understood":** `unsupportedOpenApiFields spec @?= []`.
- **"every content type is bound or explicitly excluded":** every `(method, path, where, contentType)` from `operationContentTypes` is either `application/json` or listed in `excludedContentTypes`. That list has a single entry, `("POST", "/v1/systemone", "request", "multipart/form-data")`, with a comment pointing to `docs/plans/7-send-images-with-multipart-system-one-requests.md`. The test also fails if an excluded entry no longer appears in the document, so a stale exclusion is noticed.
- **The meta-tests**, which mutate the loaded `Value` in memory with aeson's `KeyMap` and assert each audit names the fault:
  - inserting `"pattern": "^a"` into `components.schemas.Usage.properties.input_tokens` makes `unsupportedKeywords` return `["pattern"]`;
  - inserting `"callbacks": {}` into the `POST /v1/systemone` operation makes `unsupportedOpenApiFields` report it;
  - adding `"application/x-msgpack"` to the request body's `content` makes the content-type check fail.
- **Validator unit tests:** a handful of hand values. `{"input_tokens": 1, "output_tokens": 2}` is valid for `Usage`, while `1.5` as a token count fails `integer`. `"gif"` fails `Asset.format`'s `enum`. Eleven score criteria fail `maxItems`. `{}` fails `ChoiceQuestion.criteria`'s `minProperties` and `SystemOneResponse.answers`'s `minProperties`.

Register `Conformance.tests` in `test/Main.hs`. Add `tasty-hunit` to the test-suite dependencies if EP-1 did not.

Acceptance: `cabal test` passes. A manual run against a copy of the document with `"pattern"` injected fails with a message naming `pattern` (see Concrete Steps).


### Milestone 2: generators and per-schema codec checks

Create `test/TypeSafe/Test/Arbitrary.hs`, which this plan owns, with orphan `Arbitrary` instances (`{-# OPTIONS_GHC -Wno-orphans #-}`) for every bound type plus `Content`, `ModelName` and `QuestionName`. Generators must produce only values the document allows:

- **Request shapes:**
  - `questions` and `answers` have at least one entry, with unique names;
  - choice criteria have between 1 and 255 entries, with unique labels, and their values are sometimes `Nothing`;
  - score criteria have between 1 and 10 entries;
  - `Asset.format` is one of `png`, `jpg` or `jpeg`;
  - `SystemOneRequest.assets` is `Map.empty` roughly a third of the time and otherwise has 1 to 3 entries, because the document requires `minProperties: 1` whenever the key is present;
  - optional fields are `Nothing` roughly a third of the time, so every optional property, `assets` included, is both emitted and omitted across 500 samples.
- **Unions:** `Question` and `Answer` generate every known constructor. They generate `QuestionOther`/`AnswerOther` only in a separate generator used by Milestone 3, because the document's `oneOf` rejects unknown tags.
- **Content:** `Content` produces text, objects and arrays, including nested JSON with numbers, booleans and nulls inside objects and arrays, but never a top-level scalar.
- **Numbers:** `Scientific` values include ordinary decimals such as `0.12`, integers, and occasionally extreme exponents such as `1e400` and `-3e-500`, proving that the lossless path round-trips.
- **Other values:**
  - token counts are `Int` values, including `0` and occasionally `maxBound`;
  - `releaseDate` is a `YYYY-MM-DD` text;
  - `ValidationError.loc` mixes `LocationField` text segments with `LocationIndex` `Int` segments.

Port the community SDK's `genText`, which includes non-ASCII and escape characters, so that encoding is exercised on awkward strings.

In `test/TypeSafe/Conformance/Spec.hs`, add an existential binding table:

```haskell
data Binding = forall a. (Arbitrary a, ToJSON a, FromJSON a, Eq a, Show a) =>
  Binding
    { schema :: Text,
      proxy :: Proxy a,
      roundTrip :: RoundTrip,
      fields :: [FieldBinding a]
    }

data RoundTrip = ExactRoundTrip | JsonRoundTrip

-- | A schema property and the wire value the encoder must give it, read from
-- the Haskell field of the same (camel-cased) name. 'Nothing' means omitted.
data FieldBinding a = FieldBinding Text (a -> Maybe Value)
```

It has one row for each of the 20 schemas. `Question` and `Answer` are bound to the union types with no field rows. Every object schema lists one `FieldBinding` per property, except the discriminator `type` of a variant record and `Asset`'s constant `type`, which are implied. For example:

```haskell
Binding "ChoiceAnswer" (Proxy @ChoiceAnswer) ExactRoundTrip
  [ FieldBinding "choice" (\r -> Just (toJSON r.choice)),
    FieldBinding "confidence" (\r -> Just (toJSON r.confidence)),
    FieldBinding "probabilities" (\r -> Just (toJSON r.probabilities))
  ]
Binding "Usage" (Proxy @Usage) ExactRoundTrip
  [ FieldBinding "input_tokens" (\r -> Just (toJSON r.inputTokens)),
    FieldBinding "output_tokens" (\r -> Just (toJSON r.outputTokens))
  ]
Binding "SystemOneRequest" (Proxy @SystemOneRequest) JsonRoundTrip
  [ FieldBinding "questions" (\r -> Just (object [Key.fromText n .= q | (QuestionName n, q) <- toList r.questions])),
    FieldBinding "instructions" ... -- etc.
  ]
```

Use `JsonRoundTrip` for `SystemOneRequest`, `Question` and `ChoiceQuestion`, whose order-carrying vectors cannot survive decoding (see the Decision Log). Use `ExactRoundTrip` for all others.

A few notes on the table:

- **No selector functions.** The test suite also compiles under `NoFieldSelectors`, so the `Binding` and `FieldBinding` fields above produce no selector functions. Read them by pattern matching, for example `Binding name proxy rt fields`.
- **Assets.** The `assets` row reports omission explicitly: `FieldBinding "assets" (\r -> if Map.null r.assets then Nothing else Just (toJSON r.assets))`.
- **Required versus optional.** For the required-property check, `assets` is optional. Removing it from an encoded request must still decode, to a request whose `assets` is `Map.empty`.

For each binding, a `testGroup` named after the schema checks:

- **Encoded values validate:** with QuickCheck, `validate spec (schemaRef name) (toJSON x)` is empty.
- **`toEncoding` agrees with `toJSON`:** `decode (encode x) === Just (toJSON x)`.
- **Decoding inverts encoding:** under `ExactRoundTrip`, `eitherDecode (encode x) === Right x`; under `JsonRoundTrip`, `fmap toJSON (eitherDecode (encode x) :: Either String a) === Right (toJSON x)`.
- **Exactly the declared properties are emitted:** over 500 generated samples, the union of emitted top-level keys equals `objectProperties spec name`.
- **Required properties are required, and only those:** for 50 samples and each emitted key `p`, decoding the object without `p` fails exactly when `p` is in `requiredProperties spec name`.
- **Every property has a field, and the field is what the encoder writes:**
  - The table's property names, plus the implied `type` where the schema declares one, equal `objectProperties spec name` exactly. A missing row or an extra row fails.
  - For each sample and row, the property's value in `toJSON x` equals the getter's result, with `Nothing` meaning the key is absent.

The required-property check enforces several details of EP-2 and EP-3 at once: that `HTTPValidationError.detail` and every `Asset` property are optional, and that removing `type` from a `NoulQuestion` encoding fails.

Add `QuickCheck` and `tasty-quickcheck` to the test-suite dependencies, and `scientific`, `vector`, `containers` and `text` if they are not already there.

Acceptance: `cabal test` passes. Breaking a codec on purpose makes the named group fail, for example temporarily making `ChoiceAnswer`'s decoder treat `confidence` as optional. Revert the deliberate break before committing.


### Milestone 3: discriminators, unknown tags, examples and constants

Add to `test/TypeSafe/Conformance/Spec.hs`:

- **Constructors match the discriminators.** Write `knownQuestionTag :: Question -> Maybe Text` and `knownAnswerTag :: Answer -> Maybe Text` as total `case` expressions over every constructor, returning `Nothing` for `QuestionOther`/`AnswerOther`. Compile the test suite with `-Werror=incomplete-patterns`, so that adding a constructor forces an update here. Read each tag from the encoded `type` property of one sample value per constructor; do not hard-code it. Assert that the set of known tags equals `discriminatorTags spec "Question"` (and likewise for `"Answer"`); both mappings contain `box`, `choice`, `noul` and `score`. Assert also that `{"type": "box"}` decodes to the box constructor, not to `QuestionOther`.
- **Unknown tags pass through unchanged.** `{"type": "rank", "items": [1, 2]}` decodes to `QuestionOther "rank" _`, and `toJSON` of the result equals the input. The same holds for an answer `{"type": "rank", "order": [2, 1]}` and `AnswerOther`. A QuickCheck property over generated `QuestionOther`/`AnswerOther` values, whose tags are drawn from words outside the known set, checks the same re-encoding.
- **Property-level examples.** For each object schema, as in the community SDK: when every required property has an `examples` entry, the object assembled from the first example of each property validates against the schema and decodes. Also check that each property example on its own validates against that property's schema.
- **Operation-level examples.** For each entry of `operationExamples`:
  - it validates against the media object's schema;
  - a request example decodes as `SystemOneRequest`, a `200` response example as `SystemOneResponse` or `ModelMetadataList` as the schema's `$ref` says, and any other status as `HTTPValidationError`;
  - `toJSON` of the decoded value equals the example. The examples contain no explicit `null`s or unknown keys, so equality is exact.

  This covers the `box` request example, with its inline `data_base64` asset and `jev-preview` model, and the `box` response example, whose `confidence` is `null`.
- **Constants.** `serverUrls spec @?= [defaultBaseUrl]`. Both operation paths in the document equal `"/" <> Text.intercalate "/" systemOnePath` and the same for `modelsPath`. Every header parameter name in the document is one of `dangerZoneImagesHeader` or `dangerZoneLongContextHeader`, compared case-insensitively.

Acceptance: `cabal test` passes, and the listing (see Concrete Steps) shows example tests named after each example, such as `POST /v1/systemone request example box`.


### Milestone 4: operation binding (requires EP-4 M1)

Do not start this milestone until `TypeSafe.V1` exports `API`, `Routes (..)`, `SystemOneEndpoint` and `ModelsEndpoint` (EP-4 M1). Read `src/TypeSafe/V1.hs` first to learn the exact shape of the `Routes` record and the arguments each client function takes (the `Authorization` header value, the optional danger-zone header values, and the request body).

Create `test/TypeSafe/Conformance/Operations.hs`. It defines a test-only capturing monad and a `RunClient` instance for it. `RunClient` is the class in `servant-client-core`'s `Servant.Client.Core.RunClient` that servant uses to perform a request: its methods are `runRequestAcceptStatus :: Maybe [Status] -> Request -> m Response` and `throwClientError :: ClientError -> m a`.

```haskell
-- | Records every request the servant client makes and answers it with a
-- canned body, so that operations can be inspected without a network.
newtype Capture a = Capture (IORef [Request] -> LBS.ByteString -> IO a)

-- Written out because NoFieldSelectors generates no selector functions.
runCapture :: Capture a -> IORef [Request] -> LBS.ByteString -> IO a
runCapture (Capture f) = f

instance RunClient Capture where
  runRequestAcceptStatus _ request = Capture $ \ref body -> do
    modifyIORef' ref (request :)
    pure Response { responseStatusCode = status200, responseHeaders = [("Content-Type", "application/json")],
                    responseHttpVersion = http11, responseBody = body }
  throwClientError err = Capture $ \_ _ -> throwIO err
```

Write the `Functor`, `Applicative` and `Monad` instances by hand. `Request` and `Response` here are `Servant.Client.Core.Request`/`Response`. Their fields, such as `requestMethod` and `requestPath`, are ordinary selector functions defined in servant-client-core, so this module can apply them even though the project turns selectors off for its own records.

Obtain the client functions as a record with `genericClient @Routes @Capture`, imported from `Servant.Client.Generic` in servant-client-core (0.20.3; `Servant/Client/Generic.hs`). This is the same derivation EP-4's `makeMethods` uses through `genericClientHoist`. Read each route by selector application, which `TypeSafe.V1` makes possible by enabling `FieldSelectors`, for example `V1.systemOne client` and `V1.models client` with `import TypeSafe.V1 qualified as V1`. Do not use record dot syntax on `client`: a `NamedRoutes` field's type is a `(:-)` type-family application that `HasField` cannot see through, so `client.systemOne` does not typecheck. Do not destructure a `:<|>` chain either, because there is none.

Call each operation once with a token, both danger-zone headers set, and a request value: the `noul` request example decoded in Milestone 3. The canned response bodies are the operation's own `200` examples, `noul` for `POST /v1/systemone`. For `GET /v1/models`, which has no response example, use a hand-written body that validates against `ModelMetadataList`.

From the captured `Request`s, assert:

- the set of `(requestMethod, rendered requestPath)` pairs equals `specOperations spec`. This is the "every operation is bound" check; render `requestPath`, a `Builder` in servant-client-core 0.20, with `Data.ByteString.Builder.toLazyByteString`;
- each operation whose `security` names `HTTPBearer` (scheme `bearer`) sends an `Authorization` header equal to `"Bearer " <> token`;
- the header names sent, other than `Authorization` and `Accept`, are exactly that operation's declared header parameters, compared case-insensitively, and each value validates against its parameter schema (`"true"`);
- each request with a body has media type `application/json`, and its body bytes decode back to the value that was sent;
- each canned response decoded without a `ClientError`.

Add `servant-client-core` and `http-types` to the test-suite dependencies; `servant-client-core` is already a transitive dependency of `servant-client`.

Acceptance: `cabal test` passes. Temporarily removing the `models` field from a local copy of `Routes`, without committing, and its use here, makes "every operation is bound" fail naming `("GET", "/v1/models")`.


## Concrete Steps

Run everything from `/Users/shinzui/Keikaku/bokuno/typesafe-hs` inside the development shell. Run the whole suite:

```bash
nix develop -c cabal test typesafe-hs-test --test-show-details=direct
```

Run only the conformance group; tasty's `-p` takes a pattern:

```bash
nix develop -c cabal test typesafe-hs-test --test-show-details=direct \
  --test-options='-p "/OpenAPI conformance/"'
```

A passing run ends like this (counts will differ):

```text
  OpenAPI conformance
    the schema validator understands every keyword in use: OK
    every OpenAPI field in use is understood:              OK
    every content type is bound or explicitly excluded:    OK
    ...
All 214 tests passed (3.12s)
```

To prove manually, at the end of Milestone 1, that an unknown keyword fails the suite, build a mutated copy outside the repository and point the override at it:

```bash
mutant_dir=$(mktemp -d)
jq '.components.schemas.Usage.properties.input_tokens.pattern = "^a"' spec/openapi.json > "$mutant_dir/openapi.json"
TYPESAFE_OPENAPI_SPEC="$mutant_dir/openapi.json" nix develop -c cabal test typesafe-hs-test \
  --test-show-details=direct --test-options='-p "/understands every keyword/"'
```

Expected: the run fails with a message containing `pattern`, and `cabal` exits non-zero:

```text
    the schema validator understands every keyword in use: FAIL
      expected: []
       but got: ["pattern"]
```

The same technique checks the content-type audit, using `jq '.paths["/v1/systemone"].post.requestBody.content["application/x-msgpack"] = {}'`. It also checks schema binding, using `jq '.components.schemas.FooBar = {"type": "object"}'`, which makes "every schema is bound" fail naming `FooBar`.

To check a freshly published document without replacing the vendored copy, run EP-1's drift script, or fetch the document and point the override at it:

```bash
fresh_dir=$(mktemp -d)
curl -fsS https://api.typesafe.ai/openapi.json | jq -S . > "$fresh_dir/openapi.json"
TYPESAFE_OPENAPI_SPEC="$fresh_dir/openapi.json" nix develop -c cabal test typesafe-hs-test --test-show-details=direct
```

Commit at the end of each milestone. Each commit carries this plan's trailers, for example:

```text
test(conformance): audit the vendored document's keywords and content types

MasterPlan: docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ExecPlan: docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md
Intention: intention_01m5frxsb3e9et3b9mn8e31r8c
```


## Validation and Acceptance

The plan is accepted when all of the following hold on a clean checkout:

- **The full suite passes.** `nix develop -c cabal test typesafe-hs-test` passes, and the `OpenAPI conformance` group contains:
  - the three audits and their meta-tests;
  - one schema group for each of the 20 schemas;
  - the discriminator, unknown-tag, example and constant tests;
  - the operation-binding tests.
- **An unknown keyword fails the suite.** Running with `TYPESAFE_OPENAPI_SPEC` pointed at a copy containing an unknown keyword fails and names the keyword. This is R10's "a failure must be a test failure, not a silent pass", and the in-memory meta-test keeps it permanently true.
- **The suite catches the drift it exists for.**
  - A copy with an extra schema fails "every schema is bound".
  - A copy with an extra content type fails the content-type audit.
  - A copy with an extra operation, such as `jq '.paths["/v1/usage"] = {"get": {"responses": {}}}'`, fails "every operation is bound".
- **The operation examples are covered.** The `box` request and response examples from the document decode and re-encode equal.
- **The required-property checks pass for every schema.** This proves R5's strictness: a choice answer without `confidence` and a score answer without `score` both fail to decode.

`docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md` owns the loopback mock-server byte-equality check, and this plan does not duplicate it. Milestone 4's capturing client is the representative check that the servant binding and the document agree on methods, paths, headers and content types.


## Idempotence and Recovery

All work is additive test code, and every command can be rerun safely. The mutation steps write only to fresh `mktemp -d` directories and never touch `spec/openapi.json`. That file is owned by EP-1, so never edit it in this plan.

If the conformance suite fails against the vendored document because the bindings or the document disagree, do not change the document to make it pass. If the fault is in EP-2's or EP-3's codecs, fix the codec, noting the fix in this plan's Surprises & Discoveries. If the fault is a document feature nobody planned for, record the finding in the MasterPlan's Surprises & Discoveries and stop for a decision.

A deliberate break used to observe a failing test must be reverted before committing. Run `git diff src/` to confirm that the library is unchanged.


## Interfaces and Dependencies

**Prerequisites.** Per the MasterPlan's registry, this plan begins when [docs/plans/2-encode-system-one-requests-deterministically.md](2-encode-system-one-requests-deterministically.md) and [docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md](3-decode-system-one-responses-model-listings-and-error-bodies.md) are Complete. Both depend on EP-1, which provides the package, the vendored document, `TypeSafe.Wire.Common` and `test/Main.hs`. Milestone 4 additionally requires EP-4 M1 from [docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md): `TypeSafe.V1` exporting `API`, `Routes (..)`, `SystemOneEndpoint` and `ModelsEndpoint`, compiling in the library. Milestones 1 to 3 may run while the rest of EP-4 is in progress.

**Files this plan creates and owns:**

- `test/TypeSafe/Conformance/JsonSchema.hs`;
- `test/TypeSafe/Conformance/Spec.hs`, which contains the binding table and the property-to-field table and is the single place the field-naming convention is checked;
- `test/TypeSafe/Conformance/Operations.hs`;
- `test/TypeSafe/Test/Arbitrary.hs`. Other plans may import these generators but do not redefine them.

**Files this plan edits:**

- `test/Main.hs`, to register `Conformance.tests` and to load the document with the `TYPESAFE_OPENAPI_SPEC` override;
- the `test-suite typesafe-hs-test` stanza of `typesafe-hs.cabal`, for `other-modules`, `-Werror=incomplete-patterns` and the dependencies;
- `extra-source-files`, for `spec/openapi.json`, if it is missing.

**Test-suite dependencies added:** `QuickCheck`, `tasty-quickcheck`, `tasty-hunit` (if absent) and `servant-client-core`, plus `http-types`, `scientific`, `vector`, `containers`, `text`, `bytestring` and `aeson` where not already listed. Keep the bounds compatible with the library's R12 bounds in [docs/initial-spec.md](../initial-spec.md), for example `QuickCheck >=2.14 && <2.19` and `tasty-quickcheck >=0.10 && <0.12`, and verify them against the resolved build plan.

**Library code is never changed by this plan.** A codec defect found here is fixed in the owning module of EP-2 or EP-3 and noted in Surprises & Discoveries.

**Dropping an exclusion.** When [docs/plans/7-send-images-with-multipart-system-one-requests.md](7-send-images-with-multipart-system-one-requests.md) binds the multipart body, it removes the single entry of `excludedContentTypes` in `test/TypeSafe/Conformance/Spec.hs` and extends Milestone 4's capture checks to the multipart request.


## Revision Notes

- 2026-10-21: aligned with the MasterPlan's haskell-jitsurei change set. Operation binding now derives the client record with `genericClient @Routes @Capture` against EP-4's `NamedRoutes` API, and reads routes by selector application instead of `clientIn` and `:<|>`. The generators and field table follow `Int` token counts and location indices and the omitted-when-empty `assets` map. The field-table getters are confirmed to work under `NoFieldSelectors`. `Capture` became a positional newtype. The test-module style rules (explicit deriving strategies, postpositive imports, `MultilineStrings`) are stated. The decision is recorded in the Decision Log.
