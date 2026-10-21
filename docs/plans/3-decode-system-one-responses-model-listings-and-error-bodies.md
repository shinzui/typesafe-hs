---
id: 3
slug: decode-system-one-responses-model-listings-and-error-bodies
title: "Decode System One responses, model listings and error bodies"
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

# Decode System One responses, model listings and error bodies

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.

This plan is a child of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md), where it is EP-3. It cannot start until [docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md) (EP-1) is complete. It can run alongside [docs/plans/2-encode-system-one-requests-deterministically.md](2-encode-system-one-requests-deterministically.md) (EP-2), which owns the request types.


## Purpose / Big Picture

TypeSafe's System One API answers questions about a piece of content. A client sends `POST /v1/systemone` and receives a JSON body. That body holds one answer per named question, the name of the model that answered and token usage. When something goes wrong, the client receives an error body instead. `GET /v1/models` returns the list of available models.

After this plan, a Haskell program using the `typesafe-hs` library can do the following:

- **Decode success bodies.** It can turn the bytes of a success body into a `SystemOneResponse` value. Every probability, confidence and score keeps exactly the digits the server sent, so even `1e400` arrives intact instead of becoming `Infinity`.
- **Reject incomplete bodies.** Decoding fails when the server omits a field the specification requires.
- **Surface unknown answer types.** An answer whose `type` the library does not recognise comes back as an explicit `AnswerOther` value carrying the tag and the whole object. It is never dropped.
- **Read the model listing.** The program can decode the `GET /v1/models` body.
- **Parse any error body.** It can pass any error body to the pure function `parseErrorBody` and get a structured value. That value is a validation report, a structured detail, a detail string, or a raw-JSON, raw-text or empty fallback.

The library interprets nothing: it never decides whether a probability is in range, whether a status is retryable, or what an error "means". Those decisions belong to the consumer.

You can see it working in two ways:

- **Tests.** `cabal test` runs a golden test with the response fixture of Baikai, the library's first consumer. The fixture decodes to the expected values, and two damaged copies of it fail to decode.
- **REPL.** In `cabal repl`, decoding a literal body prints the decoded value.

This plan implements requirements R4, R5, R6, R9 and the response half of R11 from [docs/initial-spec.md](../initial-spec.md). Read that file's R4, R5, R6, R9 and R11 before starting; the rest of this plan explains how to meet them.


## Progress

- [ ] Milestone 1: `TypeSafe.Wire.Response` decodes and encodes success bodies. Acceptance: Baikai's response golden decodes to the expected values; the copies without `confidence` or `score` fail; `1e400` survives; a fractional token count fails; an unknown answer tag decodes to `AnswerOther` and re-encodes unchanged.
- [ ] Milestone 2: `TypeSafe.Wire.Models` decodes and encodes the model listing. Acceptance: the listing decodes with an extra unknown field present, `releaseDay` parses `2026-09-15`, and a missing `release_date` fails.
- [ ] Milestone 3: `TypeSafe.Wire.Error` has codecs for the 422 body, and `parseErrorBody` classifies every observed error form. Acceptance: each form below decodes to its expected constructor, with no status-code mapping anywhere. The full suite and `nix build` pass.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: Token counts (`Usage.inputTokens`, `Usage.outputTokens`) and validation-location indices are decoded by a hand-written parser that first reads a `Scientific`. The parser fails unless `Data.Scientific.isInteger` holds, then converts with `Data.Scientific.toBoundedInteger` at `Int64` and widens to `Integer`. Out-of-range values fail rather than allocating.
  Rationale: R4 says token counts are "rejected when the JSON number is not integral". aeson's own `FromJSON Integer` instance is documented as truncating fractional input (`3.5` would become `3`), so it must not be used. Bounding through `Int64` also avoids the memory blow-up that converting `1e1000000` straight to `Integer` would cause. If the implementer finds that aeson 2.2 rejects fractions on its own, record that under Surprises; the hand-written parser stays either way, because it states the rule explicitly.
  Date: 2026-10-21

- Decision: `BoxAnswer.confidence` is `Maybe Scientific`, decoded with aeson's `.:`, not `.:?`. The key must be present; `null` decodes to `Nothing`, and `Nothing` encodes as `null`.
  Rationale: the specification lists `confidence` as required with type number-or-null. R5 says required means required, so a body without the key must fail, while an explicit `null` is legitimate.
  Date: 2026-10-21

- Decision: `HTTPValidationError.detail` is `Maybe (Vector ValidationError)`, because the vendored document does not list `detail` as required. `parseErrorBody`, however, classifies a body as `ErrorBodyValidation` only when `detail` is present, is an array, and every element decodes as a `ValidationError`. Any other body that only looks similar falls through to `ErrorBodyJson`.
  Rationale: the type mirrors the schema exactly, as R2 and R5 require, so `{}` is a valid `HTTPValidationError`. A classifier that turned `{}` into an empty validation report would hide a body the consumer should see raw. All-or-nothing decoding of the array means a partial report is never returned.
  Date: 2026-10-21

- Decision: `ValidationError.input` is decoded by looking the key up directly in the object (`Data.Aeson.KeyMap.lookup`), not with `.:?`. An absent key is `Nothing`, and a present `null` is `Just Null`. On encode, `Nothing` is omitted.
  Rationale: `input` echoes the value that failed validation, and `null` is a meaningful value there. aeson's `.:?` collapses `null` into `Nothing`, which would lose that information.
  Date: 2026-10-21

- Decision: the structured detail form is `ErrorDetail { errorType :: Maybe Text, message :: Text }`. A `detail` object without a string `message` falls through to `ErrorBodyJson`.
  Rationale: this form is not in the specification; it has only been observed, as `{"detail": {"error_type": "api_usage_error", "message": "Unknown model: x"}}`. `message` is what the official TypeScript SDK reads; `error_type` has been seen but is not guaranteed.
  Date: 2026-10-21

- Decision: the library gains a dependency on `time`, with bound `time >=1.12 && <1.16`, for `releaseDay :: ModelMetadata -> Maybe Day`.
  Rationale: R9 asks for "a helper to parse the day". `time` is a GHC boot package, and `servant-client` 0.20.3.0, which R1 already admits, depends on `time >=1.11 && <1.16` in its library stanza. Adding it therefore adds no package to any consumer's build plan, which satisfies R1's "plus whatever servant-client itself brings" and does not narrow R12's intersection with Baikai. This was verified on 2026-10-21 in the servant source registered in Mori as `haskell-servant/servant`, at `servant/servant-client/servant-client.cabal` line 102. EP-6 owns the final bounds review.
  Date: 2026-10-21

- Decision: `decodeSystemOneResponse :: Data.ByteString.Lazy.ByteString -> Either Text SystemOneResponse` reports aeson's error message as `Text`.
  Rationale: R4's suggested `unitInterval :: Scientific -> Either Text Double` already uses `Text`, and consumers such as Baikai work in `Text`. The conversion is a single `Data.Text.pack` of aeson's message.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

This repository, `/Users/shinzui/Keikaku/bokuno/typesafe-hs`, builds one Cabal package, `typesafe-hs`, with GHC 9.12.4 inside the project's Nix development shell. Enter the shell with `nix develop`, or let `direnv` load it from `.envrc`.

**What EP-1 provides.** This plan starts after EP-1 has delivered:

- **Package files.** `typesafe-hs.cabal` and `cabal.project`. The cabal file has a common stanza enabling `GHC2024`, `DuplicateRecordFields`, `OverloadedRecordDot` and `OverloadedStrings` with `-Wall`, a `library` rooted at `src/`, and one test suite, `typesafe-hs-test`, using `tasty` and rooted at `test/` with `main-is: Main.hs`.
- **The vendored document.** The specification is at `spec/openapi.json`, normalised with `jq -S .`. It is TypeSafe's OpenAPI document, and its `info.version` is `0.2.0`.
- **Shared primitives** in `src/TypeSafe/Wire/Common.hs`:
  - `apiSpecVersion`.
  - The newtypes `ModelName` and `QuestionName` over `Text`. Each has `IsString`, `Eq`, `Ord`, `Show`, `ToJSON`, `FromJSON`, `ToJSONKey` and `FromJSONKey` instances, so `Map QuestionName a` decodes from a JSON object directly.
  - `Content`, the JSON union a description can take: `ContentText Text | ContentObject Object | ContentArray Array`. Its `FromJSON` rejects numbers, booleans and `null`. Alongside it are `contentFromValue` and `contentToValue`.
  - The constants `requestIdHeader`, `systemOnePath`, `modelsPath`, `defaultBaseUrl`, `jevLatest` and `jevPreview`.
- **The umbrella module** `src/TypeSafe/Wire.hs`, which re-exports `TypeSafe.Wire.Common`. You will add the three new modules' re-exports to it.
- **The test entry point** `test/Main.hs`. It runs a list of tasty groups; each plan registers one group there.
- **An ADR corpus** under `docs/adr/`.

Read those files before you start, because the exact names in the working tree win over this summary.

**Terms used in this plan:**

- *Wire type:* a Haskell type whose only job is to mirror one JSON schema in the specification.
- *Codec:* the pair of aeson instances that turn a wire type into JSON (`ToJSON`, including the hand-written `toEncoding` that produces bytes directly) and back (`FromJSON`).
- *Discriminator:* the `type` property that tells a noul answer from a choice answer. The specification's `Answer` schema is a `oneOf` keyed on `type`, with mapping `noul`, `choice`, `score` and `box`.
- *Golden file:* a checked-in file whose content a test compares against.
- *`Scientific`* (from the `scientific` package): an arbitrary-precision decimal number, stored as a coefficient and a base-ten exponent. aeson parses every JSON number into one, so keeping it avoids any loss.

**Schemas this plan binds.** These are taken from the vendored document; check them against `spec/openapi.json` with `jq '.components.schemas.SystemOneResponse' spec/openapi.json` and the like.

- **`SystemOneResponse`**
  - Requires `model` (string), `answers` and `usage`.
  - `answers` is an object (minimum one property) whose values are `Answer`.
  - `usage` is `Usage`.
- **`NoulAnswer`**
  - Requires `type` (the constant `"noul"`) and `noul` (a number).
- **`ChoiceAnswer`**
  - Requires `type` (`"choice"`), `choice` (a string) and `confidence` (a number).
  - Also requires `probabilities`, an object of numbers keyed by choice name.
- **`ScoreAnswer`**
  - Requires `type` (`"score"`), `score` (a number) and `confidence` (a number).
  - Requires `legend`, an object keyed `"0"`, `"1"` and so on, whose values are string, object or array, which is exactly `Content`.
  - Requires `probabilities`, an object of numbers with the same keys as `legend`.
- **`BoxAnswer`**
  - Requires `type` (`"box"`) and `box`, a `BoxCoordinates`.
  - Also requires `confidence`, which is a number or `null`.
- **`BoxCoordinates`**
  - Requires `top`, `bottom`, `left` and `right`, all numbers.
- **`Usage`**
  - Requires `input_tokens` and `output_tokens`, both of type `integer`.
- **`ModelMetadataList`**
  - Requires `models`, an array of `ModelMetadata`.
- **`ModelMetadata`**
  - Requires `name`, `description` and `release_date`, all strings.
  - `release_date` is formatted `YYYY-MM-DD`.
- **`HTTPValidationError`**
  - Has an optional `detail`, an array of `ValidationError`.
  - It is the body of HTTP 422 on both operations.
- **`ValidationError`**
  - Requires `loc`, an array whose items are each a string or an integer.
  - Requires `msg` (a string) and `type` (a string).
  - Has an optional `input` (any JSON) and an optional `ctx` (an object).

**Error forms outside the specification.** The service also sends error bodies the specification does not describe. These were observed through the official TypeScript SDK, at the local checkout `/Users/shinzui/Keikaku/hub/agents/typesafe-sdk-js` (v0.7.0), in `src/errors.ts` and `test/errors.test.ts`:

- an unknown model gives HTTP 400 with `{"detail": {"error_type": "api_usage_error", "message": "Unknown model: x"}}`;
- some failures send `{"detail": "fastapi style"}`;
- 401 replies send `{"error": {"message": "invalid api key"}}`;
- other bodies seen are `{"error": "plain string"}` and `{"message": "top-level message"}`;
- gateways can return HTML such as `<h1>bad gateway</h1>`;
- a 429 can arrive with an empty body.

R6 requires codecs only for the `detail` forms. The `error` and `message` forms land in the raw-JSON fallback, and tests must show that they do.

**Naming conventions**, decided in the masterplan and to be checked later by EP-5's conformance suite:

- A Haskell field takes the property's name verbatim, without a type-name prefix.
- Snake case becomes lower camel case: `input_tokens` becomes `inputTokens`, and `release_date` becomes `releaseDate`.
- The reserved word `type` becomes `type_` where it is a real field (`ValidationError`).
- The discriminator `type` on answers is implied by the constructor and is not a field.

Because several records share field names (`confidence` appears on three answers, `probabilities` on two), the package enables `DuplicateRecordFields`. Read fields with `OverloadedRecordDot` (`answer.confidence`), and build values with record construction syntax. Avoid record-update syntax on these types, which is ambiguous under `DuplicateRecordFields`.

**ADRs.** At the time this plan was written, `docs/adr/` did not exist; EP-1 creates it. Two of the records EP-1 writes govern this plan:

- **Wire types mirror the vendored specification.** This one covers naming, both codec directions, lossless numbers, no semantic validation in decoders, and surfaced unknown tags.
- **The library carries no transport policy.** No retries, no status classification and no environment lookups.

List `docs/adr/` and cite both by their repository-relative paths when you implement. The second record cites Baikai's decision that its core, not a provider dependency, classifies transport failures. That decision is `mori://shinzui/baikai`, project-relative path `docs/adr/0011-core-owns-transport-failure-classification.md` (artifact-level URI pending; Mori's concept registry returned no handle on 2026-10-21). It is why `parseErrorBody` must never look at a status code.


## Plan of Work

The work adds three library modules and their tests, in three milestones that can each be verified alone. All new library modules go under `src/TypeSafe/Wire/`, and each is added to `exposed-modules` in `typesafe-hs.cabal` and re-exported from `src/TypeSafe/Wire.hs`. All new test modules go under `test/TypeSafe/Wire/` and are added to the test suite's `other-modules`. Register one tasty group, `Wire.Response`, in `test/Main.hs`, holding the three milestones' subgroups, as the masterplan asks one group per plan. Golden files go under `test/golden/`, which this plan owns for its response files, and are listed in the cabal file's `extra-source-files` so that the source distribution carries them. The tests read them by paths relative to the package root, which is the working directory `cabal test` uses.

Each type derives `Eq` and `Show` and gets hand-written `FromJSON` and `ToJSON` instances:

- **Unknown keys.** Decoders ignore unknown keys, for forward compatibility (R5).
- **No semantic checks.** Decoders apply no semantic checks: a confidence of `1.5` or a negative token count decodes, because the schema allows it (R4).
- **Hand-written `toEncoding`.** Each `ToJSON` instance has a hand-written `toEncoding` built with `Data.Aeson.Encoding.pairs`, emitting keys in the schema's `required` order with `type` first.
- **Agreement with `toJSON`.** The `toJSON` must agree with it structurally, meaning that `decode (encode x) :: Maybe Value` equals `Just (toJSON x)`.
- **Why encoders exist.** The encoders exist because EP-4's mock server must send responses, and EP-5 checks that decoding inverts encoding for every schema.


### Milestone 1: success bodies

Create `src/TypeSafe/Wire/Response.hs` with:

- **The success body.** `SystemOneResponse { model :: !ModelName, answers :: !(Map QuestionName Answer), usage :: !Usage }`.
- **The answer sum.** `Answer` has the constructors `AnswerNoul !NoulAnswer`, `AnswerChoice !ChoiceAnswer`, `AnswerScore !ScoreAnswer`, `AnswerBox !BoxAnswer` and `AnswerOther !Text !Object`.
- **One record per answer schema:**
  - `NoulAnswer { noul :: !Scientific }`.
  - `ChoiceAnswer { choice :: !Text, confidence :: !Scientific, probabilities :: !(Map Text Scientific) }`.
  - `ScoreAnswer { score :: !Scientific, confidence :: !Scientific, legend :: !(Map Text Content), probabilities :: !(Map Text Scientific) }`.
  - `BoxAnswer { box :: !BoxCoordinates, confidence :: !(Maybe Scientific) }`.
  - `BoxCoordinates { top, bottom, left, right :: !Scientific }`.
  - `Usage { inputTokens :: !Integer, outputTokens :: !Integer }`.
- **Decoding and helpers.** `decodeSystemOneResponse`, plus two pure helpers that the decoders never call:
  - `unitInterval :: Scientific -> Either Text Double`, which succeeds only for values in [0, 1];
  - `finiteDouble :: Scientific -> Either Text Double`, which uses `Data.Scientific.toBoundedRealFloat` and returns `Left` when the value does not fit a finite `Double`.

`FromJSON Answer` works in three steps:

- **Read the tag.** It reads `type` as a string; a missing or non-string `type` is a decoding failure.
- **Known tags.** For `noul`, `choice`, `score` and `box` it decodes the matching record from the same object. A malformed known answer fails; it is never demoted to `AnswerOther`.
- **Unknown tags.** For any other tag it returns `AnswerOther tag object`, keeping the complete object, including its `type` key.

Each variant record (`NoulAnswer`, `ChoiceAnswer`, `ScoreAnswer`, `BoxAnswer`) owns its tag in both directions: its own `toEncoding` and `toJSON` write `"type"` first, followed by its fields, and its own `FromJSON` requires `"type"` with the right value. `ToJSON Answer` and `FromJSON Answer` only dispatch to the variant instances. This matters because the specification marks `type` as required on each variant schema, and EP-5's conformance suite encodes and decodes the variant records on their own. For `AnswerOther`, it writes the stored object unchanged. Required keys use `.:`. All numbers are decoded as `Scientific`. `Usage` uses the bounded integral parser described in the Decision Log. Milestone 3's location indices need the same rule, so put the parser (for example `parseBoundedIntegral :: Value -> Parser Integer`) in an internal module `src/TypeSafe/Wire/Internal/Number.hs`, listed in the library's `other-modules` so it is shared without being exported.

Write the golden files:

- `test/golden/baikai-response.json`, which is R11's response, verbatim:

```json
{
  "answers": {
    "urgent": {"type": "noul", "noul": 0.83},
    "category": {"type": "choice", "probabilities": {"billing": 0.2, "technical": 0.7}, "choice": "technical", "confidence": 0.65},
    "severity": {"type": "score", "probabilities": {"0": 0.1, "1": 0.3, "2": 0.6}, "score": 1.5, "confidence": 0.55, "legend": {"0": "Minor", "1": "Disruptive", "2": "Blocking"}}
  },
  "usage": {"input_tokens": 120, "output_tokens": 3},
  "model": "jev-fixture-version"
}
```

- `test/golden/baikai-response-missing-confidence.json`, the same file with `"confidence": 0.65` removed from `category`.
- `test/golden/baikai-response-missing-score.json`, the same file with `"score": 1.5` removed from `severity`.

Create `test/TypeSafe/Wire/ResponseTests.hs` with a subgroup `success bodies` whose tests assert:

- **The golden decodes** to a value equal to a hand-built `SystemOneResponse`:
  - model `"jev-fixture-version"`;
  - `urgent` is `AnswerNoul (NoulAnswer 0.83)`;
  - `category` has choice `"technical"`, confidence `0.65` and probabilities billing `0.2`, technical `0.7`;
  - `severity` has score `1.5`, confidence `0.55`, legend `"0"` to `ContentText "Minor"`, `"1"` to `"Disruptive"` and `"2"` to `"Blocking"`, and probabilities `0.1`, `0.3`, `0.6`;
  - usage `120` and `3`.

  Use `Scientific` literals such as `0.83`, which are exact.
- **The two negative goldens fail.** Each returns `Left`.
- **Required fields fail when removed.** Each body fails with the named field removed:
  - top-level `model`, `answers` or `usage`;
  - `usage.input_tokens` or `usage.output_tokens`;
  - `legend` or `probabilities` from a score answer;
  - `box.top`;
  - box `confidence`.
- **A null box confidence is allowed.** A box answer with `"confidence": null` decodes to `Nothing`.
- **Huge numbers survive.** A noul answer `{"type": "noul", "noul": 1e400}` decodes to `Data.Scientific.scientific 1 400`. `finiteDouble` of that value returns `Left`, and `unitInterval 1.5` returns `Left`. A choice answer with `"confidence": 1.5` still decodes: the wire layer does not validate.
- **Token counts must be integral.** `{"input_tokens": 3.5, "output_tokens": 1}` fails, and `{"input_tokens": 1.2e3, "output_tokens": 0}` decodes to `1200`, because it is integral.
- **Unknown tags are surfaced.** An answer `{"type": "polygon", "points": [1, 2]}` decodes to `AnswerOther "polygon" obj`, where `obj` still contains both keys. Encoding it gives back a structurally equal object.
- **Bad tags fail.** An answer with no `type`, or with `"type": 7`, fails.
- **Unknown keys are ignored.** A known answer with an extra key such as `"rationale": "x"` decodes.
- **Encoding round-trips.** For the golden value and for one box answer, `eitherDecode (encode x) == Right x`, and `toEncoding` agrees with `toJSON` as defined above.

The score example from the vendored document is a useful extra literal. Decoding the document's own examples systematically is EP-5's job, so do not build that machinery here:

```json
{"model":"jev-latest","answers":{"urgency":{"type":"score","score":1.7,"confidence":0.55,"legend":{"0":"Can wait","1":"Needs attention this week","2":"Needs attention today"},"probabilities":{"0":0.1,"1":0.1,"2":0.8}}},"usage":{"input_tokens":120,"output_tokens":12}}
```

At the end of Milestone 1, `cabal test` runs the `success bodies` subgroup and all of it passes.


### Milestone 2: model listing

Create `src/TypeSafe/Wire/Models.hs` with:

- `ModelMetadataList { models :: !(Vector ModelMetadata) }`.
- `ModelMetadata { name :: !ModelName, description :: !Text, releaseDate :: !Text }`, where the JSON key is `release_date`.
- `releaseDay :: ModelMetadata -> Maybe Data.Time.Calendar.Day`. Parse with `Data.Time.Format.ISO8601.iso8601ParseM` on `releaseDate`, so that `2026-09-15` gives `fromGregorian 2026 9 15` and `2026-13-01` gives `Nothing`.

`releaseDate` stays `Text` so that decoding never fails on an unusual date (R9). Add `time` to the library's `build-depends` with the bound recorded in the Decision Log.

Add a subgroup `model listing` to `test/TypeSafe/Wire/ResponseTests.hs`, or to a sibling module `test/TypeSafe/Wire/ModelsTests.hs` registered under the same `Wire.Response` group. Its tests assert:

- **A real listing decodes.** This body decodes, ignoring `tags`, and `releaseDay` of its first model is `Just (fromGregorian 2026 9 15)`:

```json
{"models": [{"name": "jev-latest", "description": "General-purpose system one model.", "release_date": "2026-09-15", "tags": ["default"]}]}
```

- **Required fields fail when removed.** Removing `release_date`, `name`, `description` or `models` fails.
- **A bad date still decodes.** `"release_date": "soon"` decodes, and `releaseDay` returns `Nothing`.
- **Encoding round-trips.**


### Milestone 3: error bodies

Create `src/TypeSafe/Wire/Error.hs` with:

- `LocationSegment`, with the constructors `LocationField !Text | LocationIndex !Integer`.
  - Decoding a string gives a field.
  - Decoding an integral number gives an index, using the bounded integral rule.
  - Anything else fails.
- `ValidationError { loc :: !(Vector LocationSegment), msg :: !Text, type_ :: !Text, input :: !(Maybe Value), ctx :: !(Maybe Object) }`. The JSON key of `type_` is `type`, and `input` follows the direct-lookup rule in the Decision Log.
- `HTTPValidationError { detail :: !(Maybe (Vector ValidationError)) }`.
- `ErrorDetail { errorType :: !(Maybe Text), message :: !Text }`. The JSON key of `errorType` is `error_type`.
- The `ErrorBody` sum:

```haskell
data ErrorBody
  = ErrorBodyValidation !HTTPValidationError -- {"detail": [ValidationError, ...]}
  | ErrorBodyDetail !ErrorDetail             -- {"detail": {"error_type": ..., "message": ...}}
  | ErrorBodyDetailText !Text                -- {"detail": "..."}
  | ErrorBodyJson !Value                     -- any other JSON document
  | ErrorBodyText !Text                      -- bytes that are not JSON
  | ErrorBodyEmpty                           -- zero bytes
```

- `parseErrorBody :: Data.ByteString.Lazy.ByteString -> ErrorBody`, which is total. It classifies in this order:
  1. Zero bytes give `ErrorBodyEmpty`.
  2. Bytes that are not a JSON document give `ErrorBodyText`, decoded with `Data.Text.Encoding.decodeUtf8Lenient`, so invalid UTF-8 becomes replacement characters instead of an exception.
  3. A JSON object whose `detail` is an array, every element of which decodes as `ValidationError`, gives `ErrorBodyValidation`.
  4. An object whose `detail` is an object with a string `message` gives `ErrorBodyDetail`.
  5. An object whose `detail` is a string gives `ErrorBodyDetailText`.
  6. Everything else gives `ErrorBodyJson` with the parsed value.

It takes only the bytes: no status code, no headers, no retryability and no exception type. Give `ToJSON` instances to `LocationSegment`, `ValidationError`, `HTTPValidationError` and `ErrorDetail`, because EP-4's mock server replies with a 422 body built from them. `ErrorBody` itself needs no codec.

Add a subgroup `error bodies` with one test per form. Each body and its expected result:

- `{"detail": [{"type": "list_type", "loc": ["body", "questions", "q", "score", "criteria"], "msg": "Input should be a valid list"}, {"type": "too_short", "loc": ["body", "questions"], "msg": "Dictionary should have at least 1 item"}]}` gives `ErrorBodyValidation` with two entries. Every `loc` segment of the first is a `LocationField`, and `type_` is `"list_type"`.
- `{"detail": [{"loc": ["body", "questions", "q", "score", "criteria", 0], "msg": "Field required", "type": "missing", "input": null, "ctx": {"min_length": 1}}]}` gives a final segment of `LocationIndex 0`, `input == Just Null` and `ctx` present.
- `{"detail": {"error_type": "api_usage_error", "message": "Unknown model: x"}}` gives `ErrorBodyDetail (ErrorDetail (Just "api_usage_error") "Unknown model: x")`.
- `{"detail": "fastapi style"}` gives `ErrorBodyDetailText "fastapi style"`.
- `{"error": {"message": "invalid api key"}}`, `{"error": "plain string"}`, `{"message": "top-level message"}` and `{"code": 7}` each give `ErrorBodyJson` of exactly that value.
- `{"detail": [{"msg": "no loc"}]}` gives `ErrorBodyJson`: an element is not a valid `ValidationError`, so there is no partial report.
- `{"detail": [{"loc": [1.5], "msg": "m", "type": "t"}]}` gives `ErrorBodyJson`, because the index is not integral.
- `<h1>bad gateway</h1>` gives `ErrorBodyText "<h1>bad gateway</h1>"`.
- The bytes `0xff 0xfe` give `ErrorBodyText` holding replacement characters, and the test must not throw.
- The empty string gives `ErrorBodyEmpty`.
- Decoding `HTTPValidationError` directly from `{}` gives `Right (HTTPValidationError Nothing)`.
- Encoding round-trips for one `ValidationError` with `input` and `ctx` present.

Finish by re-exporting all three modules from `src/TypeSafe/Wire.hs`, then run the full suite and `nix build`.


## Concrete Steps

Run every command from the repository root, `/Users/shinzui/Keikaku/bokuno/typesafe-hs`, inside the development shell. Prefix each with `nix develop -c` if `direnv` is not active.

Confirm the starting point, which is EP-1 complete:

```bash
nix develop -c cabal build all
nix develop -c cabal test typesafe-hs-test --test-show-details=direct
```

Both succeed before you begin. If `src/TypeSafe/Wire/Common.hs` or `test/Main.hs` is missing, EP-1 is not complete; stop.

While developing a milestone, run only this plan's group. The `-p` option is tasty's pattern filter:

```bash
nix develop -c cabal test typesafe-hs-test --test-show-details=direct --test-options='-p /Wire.Response/'
```

Expected tail at the end of Milestone 3 (test counts will vary with the exact cases you write):

```text
    Wire.Response
      success bodies
        baikai golden decodes to the expected values:  OK
        golden without confidence fails:              OK
        golden without score fails:                   OK
        1e400 survives decoding:                      OK
        fractional token count fails:                 OK
        unknown answer tag is surfaced:               OK
        ...
      model listing
        ...
      error bodies
        ...

All 40 tests passed (0.02s)
```

To see decoding by hand:

```bash
nix develop -c cabal repl typesafe-hs
```

```text
ghci> :set -XOverloadedStrings
ghci> import TypeSafe.Wire
ghci> decodeSystemOneResponse "{\"model\":\"m\",\"answers\":{\"q\":{\"type\":\"noul\",\"noul\":1e400}},\"usage\":{\"input_tokens\":1,\"output_tokens\":2}}"
Right (SystemOneResponse {model = ModelName "m", answers = fromList [(QuestionName "q",AnswerNoul (NoulAnswer {noul = 1.0e400}))], usage = Usage {inputTokens = 1, outputTokens = 2}})
ghci> parseErrorBody "{\"detail\":\"nope\"}"
ErrorBodyDetailText "nope"
```

The exact `Show` output of the newtypes depends on how EP-1 derived them; what matters is `1.0e400` rather than `Infinity`.

Before committing, format and check:

```bash
nix fmt
nix develop -c cabal test typesafe-hs-test --test-show-details=direct
nix build
```

Commit at the end of each milestone, using Conventional Commits and these trailers:

```text
feat(wire): decode System One success bodies losslessly

Add TypeSafe.Wire.Response with Scientific-valued answers, strict
required fields, AnswerOther for unknown tags, and Baikai's response
golden with its two negative variants.

MasterPlan: docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ExecPlan: docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md
Intention: intention_01m5frxsb3e9et3b9mn8e31r8c
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

**R11 response half.** `test/golden/baikai-response.json` decodes to the hand-built expected value, with `confidence`, `score` and `legend` present. Decoding fails for `test/golden/baikai-response-missing-confidence.json` and for `test/golden/baikai-response-missing-score.json`.

**R4.** The number `1e400` decodes intact as a `Scientific`. `finiteDouble` and `unitInterval` reject out-of-range values, but the decoders never call them. A fractional token count fails, and an integral one written in exponent form succeeds.

**R5.** Removing any required key listed in Milestone 1 makes decoding fail. Unknown extra keys are ignored. An unknown answer tag decodes to `AnswerOther` with the complete object, and that object re-encodes unchanged. A malformed known answer fails rather than becoming `AnswerOther`.

**R6.** `parseErrorBody` returns the expected constructor for every body in Milestone 3, including the bodies outside the specification. Searching the new modules finds no status code and no retry vocabulary:

```bash
grep -nE 'Status|status|retry|Retry|4[0-9][0-9]|5[0-9][0-9]' src/TypeSafe/Wire/Error.hs src/TypeSafe/Wire/Response.hs
```

The search prints nothing, apart from numeric literals unrelated to HTTP if any exist; inspect any hit.

**R9.** The model listing decodes, with unknown fields ignored, and `releaseDay` parses the date.

**Encoders.** Every new type round-trips through `encode` and `eitherDecode`, and its `toEncoding` agrees structurally with `toJSON`.

**Whole suite.** `cabal test typesafe-hs-test` passes in full, so nothing from EP-1 or EP-2 regresses. `nix build` succeeds; it builds the package with Nix and runs its test suite.

**Representative consumer check.** This plan's codecs are consumed by EP-4's loopback mock server and by EP-5's conformance suite, and those plans own the integration exercises. The golden test here already exercises the exact body Baikai's provider will receive, so no further integration fixture is required in this plan.


## Idempotence and Recovery

All steps are additive: new modules, new test modules, new golden files, and one-line additions to `typesafe-hs.cabal`, `src/TypeSafe/Wire.hs` and `test/Main.hs`. Re-running the build and tests is always safe.

**If EP-2 lands in parallel and the shared files conflict,** keep both sides' additions. The edits are independent lines in module lists, export lists and the test-group list.

**If the vendored document disagrees with a schema summary in this plan,** the document wins. Implement what `spec/openapi.json` says and record the difference under Surprises & Discoveries. Do not edit or re-vendor `spec/openapi.json`: EP-1 owns it, and drift is a masterplan-level decision. Record it in the masterplan's Surprises & Discoveries and stop for a decision.

**To back out a milestone,** revert its commit; earlier milestones do not depend on later ones.


## Interfaces and Dependencies

**Library dependencies used here.** These are all within R12's bounds, and `time` is newly added (see the Decision Log):

- `aeson ^>=2.2`: `Data.Aeson`, `Data.Aeson.Encoding`, `Data.Aeson.KeyMap`, `Data.Aeson.Key` and `Data.Aeson.Types`.
- `scientific ^>=0.3`: `Data.Scientific`.
- `containers ^>=0.7`: `Data.Map.Strict`.
- `vector ^>=0.13`: `Data.Vector`.
- `text ^>=2.1`: `Data.Text` and `Data.Text.Encoding`.
- `bytestring ^>=0.12`: `Data.ByteString.Lazy`.
- `time >=1.12 && <1.16`: `Data.Time.Calendar` and `Data.Time.Format.ISO8601`.

**Test dependencies.** `tasty` and `tasty-hunit` are already present from EP-1; add `scientific`, `containers`, `vector`, `bytestring`, `aeson` and `time` to the test suite if EP-1 did not.

**Prerequisite.** EP-1, [docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md), must be Complete. This plan consumes these EP-1 names from `TypeSafe.Wire.Common`: `ModelName`, `QuestionName`, `Content` and its constructors, and their aeson instances, including `FromJSONKey QuestionName`. It does not use EP-2's request types.

**Interfaces this plan defines.** Other plans depend on these:

```haskell
-- src/TypeSafe/Wire/Response.hs
module TypeSafe.Wire.Response
  ( SystemOneResponse (..), Answer (..), NoulAnswer (..), ChoiceAnswer (..),
    ScoreAnswer (..), BoxAnswer (..), BoxCoordinates (..), Usage (..),
    decodeSystemOneResponse, unitInterval, finiteDouble )

data SystemOneResponse = SystemOneResponse
  { model :: !ModelName, answers :: !(Map QuestionName Answer), usage :: !Usage }
data Answer
  = AnswerNoul !NoulAnswer | AnswerChoice !ChoiceAnswer | AnswerScore !ScoreAnswer
  | AnswerBox !BoxAnswer | AnswerOther !Text !Object
data NoulAnswer = NoulAnswer { noul :: !Scientific }
data ChoiceAnswer = ChoiceAnswer
  { choice :: !Text, confidence :: !Scientific, probabilities :: !(Map Text Scientific) }
data ScoreAnswer = ScoreAnswer
  { score :: !Scientific, confidence :: !Scientific
  , legend :: !(Map Text Content), probabilities :: !(Map Text Scientific) }
data BoxAnswer = BoxAnswer { box :: !BoxCoordinates, confidence :: !(Maybe Scientific) }
data BoxCoordinates = BoxCoordinates
  { top :: !Scientific, bottom :: !Scientific, left :: !Scientific, right :: !Scientific }
data Usage = Usage { inputTokens :: !Integer, outputTokens :: !Integer }

decodeSystemOneResponse :: Data.ByteString.Lazy.ByteString -> Either Text SystemOneResponse
unitInterval :: Scientific -> Either Text Double
finiteDouble :: Scientific -> Either Text Double

-- src/TypeSafe/Wire/Models.hs
data ModelMetadataList = ModelMetadataList { models :: !(Vector ModelMetadata) }
data ModelMetadata = ModelMetadata
  { name :: !ModelName, description :: !Text, releaseDate :: !Text }
releaseDay :: ModelMetadata -> Maybe Data.Time.Calendar.Day

-- src/TypeSafe/Wire/Error.hs
data LocationSegment = LocationField !Text | LocationIndex !Integer
data ValidationError = ValidationError
  { loc :: !(Vector LocationSegment), msg :: !Text, type_ :: !Text
  , input :: !(Maybe Value), ctx :: !(Maybe Object) }
data HTTPValidationError = HTTPValidationError { detail :: !(Maybe (Vector ValidationError)) }
data ErrorDetail = ErrorDetail { errorType :: !(Maybe Text), message :: !Text }
data ErrorBody = ErrorBodyValidation !HTTPValidationError | ErrorBodyDetail !ErrorDetail
  | ErrorBodyDetailText !Text | ErrorBodyJson !Value | ErrorBodyText !Text | ErrorBodyEmpty
parseErrorBody :: Data.ByteString.Lazy.ByteString -> ErrorBody
```

Every type has `Eq`, `Show`, `FromJSON` and `ToJSON`, the last with a hand-written `toEncoding`, except `ErrorBody`, which has `Eq` and `Show` only. `TypeSafe.Wire` re-exports all of the above.

**Consumers:**

- EP-4 ([docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md)) uses `SystemOneResponse` and `ModelMetadataList` in the servant `API` type. Its mock server uses their `ToJSON` instances and `HTTPValidationError`'s, and it uses `parseErrorBody` on `FailureResponse` bodies. It also reuses `test/golden/baikai-response.json`.
- EP-5 ([docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md)) binds each of these types to its schema name: `SystemOneResponse`, `Answer`, `NoulAnswer`, `ChoiceAnswer`, `ScoreAnswer`, `BoxAnswer`, `BoxCoordinates`, `Usage`, `ModelMetadataList`, `ModelMetadata`, `HTTPValidationError` and `ValidationError`. It checks the property-to-field names described above. `ErrorDetail` and `ErrorBody` have no schema and are not bound.
