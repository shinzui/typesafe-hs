---
id: 2
slug: encode-system-one-requests-deterministically
title: "Encode System One requests deterministically"
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
  reviews:
    - model: "claude-fable-5-1"
      harness: "claude-code"
      at: 2026-10-22T03:15:28Z
      verdict: "comments"
      note: "Schema facts, nullability rules and golden bytes verified against the live document; say who lists its golden files in extra-source-files"
---

# Encode System One requests deterministically

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a Haskell program can describe a request to TypeSafe's System One API (`POST /v1/systemone`) as an ordinary record value and turn it into the exact JSON bytes that will be sent. The value holds a model name, the content being judged (the "state"), and an ordered set of named questions: yes/no ("noul"), choice, score and box. The same value always encodes to the same bytes. Questions and choice labels appear on the wire in the order the caller declared them. Absent optional fields are left out, and the only nulls written are the ones the caller asked for. Question types this library does not know pass through unchanged.

This is what the first consumer, Baikai's `baikai-typesafe` provider (`mori://shinzui/baikai/plans/84-deliver-the-typesafe-system-one-provider-and-judgment-catalog`), needs. It commits to the bytes it sends as call evidence and asserts them on a loopback server. It also keeps its callers' enum order.

You can see it working by running the test suite. A golden test (a test that compares output against a checked-in expected file) encodes Baikai's three-question fixture request. It shows that the output is structurally equal to `test/golden/baikai-request.json` and byte-for-byte equal to `test/golden/baikai-request.bytes`.

The governing requirements are R2, R3, R7, R8 and R11 in [docs/initial-spec.md](../initial-spec.md). This plan is child EP-2 of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md).


## Progress

- [ ] Milestone 1: `src/TypeSafe/Wire/Request.hs` defines every request type with `ToJSON` (hand-written `toEncoding`) and `FromJSON`, plus `encodeSystemOneRequest`, `duplicateQuestionNames` and `duplicateChoiceLabels`. The umbrella `TypeSafe.Wire` re-exports them. `cabal build all` succeeds with no warnings from the new module.
- [ ] Milestone 2: the `TypeSafe.Wire.Request` tasty group passes under `cabal test`. It covers the R11 golden request (structural and exact bytes), determinism, declared order, the absent-versus-null rules, `QuestionOther` pass-through, duplicate reporting and decode of each question variant.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: the fixed key orders are:
  - top level: `model`, `state`, `questions`, `assets`;
  - every question: `type`, `instructions`, `criteria`;
  - noul criteria: `true`, `false`;
  - `Asset`: `type`, `format`, `data_base64`, `part`.

  Rationale: R3 requires a fixed order. This order matches the reading order of R11's fixture, which puts `model` first and `type` first in each question. The JSON Schema `required` lists are not usable as an order source, because they differ between published copies of the document.
  Date: 2026-10-21

- Decision: encoding never removes duplicate question names or choice labels. A `Vector` with two entries named `"a"` encodes as a JSON object with two `"a"` keys. Duplicates are reported by the pure functions `duplicateQuestionNames :: SystemOneRequest -> [QuestionName]` and `duplicateChoiceLabels :: ChoiceQuestion -> [Text]`, each returning every repeated name once, in order of first repetition.
  Rationale: R3 says uniqueness is "checked by a smart constructor or reported by a pure validation function, not silently collapsed". The parent MasterPlan chose plain `Vector` fields with reporting functions. Collapsing would hide a caller error that Baikai's validator wants to report.
  Date: 2026-10-21

- Decision (superseded by the `Map Text Asset` entry below, 2026-10-21): the request type `assets` field is `Maybe (Map Text Asset)`, with `Nothing` omitted. The map's key order (ascending `Text`) is the encoding order.
  Rationale: asset placeholders carry no caller-meaningful order, and a `Map` is already deterministic. R3's ordered-sequence rule applies to questions and choice criteria only.
  Date: 2026-10-21

- Decision: `assets` is a plain `Map Text Asset`. It is encoded only when non-empty, an empty map is omitted, and an absent key decodes to `Map.empty`. The map's key order (ascending `Text`) is still the encoding order.
  Rationale: `Maybe (Map Text Asset)` had two ways to say "no assets" (`Nothing` and `Just Map.empty`). An empty map is invalid on the wire anyway, because the document sets `minProperties: 1`. Encoding a decoded `"assets": {}` therefore drops the key; that is acceptable because such input is outside the schema. This is change C6 of the parent MasterPlan's alignment with haskell-jitsurei.
  Date: 2026-10-21

- Decision: the module follows the haskell-jitsurei conventions adopted by the parent MasterPlan:
  - postpositive qualified imports (`import Data.Vector qualified as Vector`), from `mori://shinzui/haskell-jitsurei/docs/core-standards`;
  - an explicit `deriving stock (Generic, Eq, Show)` on every type, with no deriving clause lacking a strategy, from `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`;
  - `NoFieldSelectors`, so record fields are read with record dot syntax or generic-lens `#label`, and are never exported as top-level functions.

  JSON instances stay hand-written.
  Rationale: `DeriveAnyClass` is on in the common stanza, so a deriving clause without a strategy could silently produce an empty instance. `Generic` lets consumers who follow jitsurei's record pattern use `#instructions` and `#criteria` without this library depending on `lens`, which R1 forbids. `NoFieldSelectors` stops fields named `state`, `model`, `true` and `false` from becoming functions that clash with mtl's `state` or with a consumer's own names. Generic aeson is ruled out, because R3 needs fixed key orders and the absent-versus-null rules.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

The repository is `typesafe-hs`, a Haskell library for TypeSafe's System One HTTP API. Its requirements live in [docs/initial-spec.md](../initial-spec.md), as numbered requirements R1 to R12. The coordination document for the initiative is [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md). Its Integration Points and Decision Log sections are binding on this plan and are summarised below where they matter.

**Prerequisite: EP-1.** This plan starts only after [docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md) is Complete. That plan provides the following:

- **`typesafe-hs.cabal` and `cabal.project` at the repository root.** The package has a common stanza: `GHC2024`, the haskell-jitsurei baseline extensions `DeriveAnyClass`, `DuplicateRecordFields`, `OverloadedLabels` and `OverloadedStrings`, plus `NoFieldSelectors` and `OverloadedRecordDot`, and `-Wall`. The test suite adds `MultilineStrings`, and `cabal.project` makes `-Werror=missing-fields` fatal for local builds. It also has a `library` with `hs-source-dirs: src`, and one test suite, `typesafe-hs-test`, using `tasty`, with `hs-source-dirs: test` and `main-is: Main.hs`.
- **`spec/openapi.json`.** TypeSafe's OpenAPI document, the machine-readable API description, as published at https://api.typesafe.ai/openapi.json on 2026-10-21. It is normalised with `jq -S .` and its `info.version` is `0.2.0`.
- **`src/TypeSafe/Wire/Common.hs`.** The shared primitives:
  - `apiSpecVersion`;
  - `newtype ModelName = ModelName Text` and `newtype QuestionName = QuestionName Text`, both with `deriving stock (Generic, Show)` and `deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)`;
  - `jevLatest` and `jevPreview`;
  - `data Content = ContentText Text | ContentObject Object | ContentArray Array`. Its `ToJSON` includes `toEncoding`, and its `FromJSON` rejects numbers, booleans and null;
  - `contentFromValue` and `contentToValue`;
  - the path, header and base-URL constants.
- **`src/TypeSafe/Wire.hs`.** The umbrella module, which currently re-exports `TypeSafe.Wire.Common`.
- **`test/Main.hs`.** The tasty entry point, where each plan registers one test group.
- **`docs/adr/`.** The ADR corpus, which includes a record that the wire types mirror the vendored specification.

If any of these differ in the working tree, follow the working tree and note the difference in Surprises & Discoveries.

The parallel sibling [docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md](3-decode-system-one-responses-model-listings-and-error-bodies.md) (EP-3) owns the response, model-listing and error modules. It does not touch `src/TypeSafe/Wire/Request.hs`. The two plans share only three things, each an additive one-line edit: the export list of `src/TypeSafe/Wire.hs`, the module lists in `typesafe-hs.cabal`, and the test registration in `test/Main.hs`.

**Terms.**
- *Encoding* means aeson's `Data.Aeson.Encoding`: a builder that writes JSON text directly without first constructing an aeson `Value` tree.
- *`toEncoding`* is the `ToJSON` method that produces such a builder. aeson's `encode` uses it, and so does servant's `JSON` content type, which EP-4 relies on.
- *`pairs`* turns a `Series` (a concatenation of `key .= value` entries built with `<>`) into an object encoding. The entries keep the order in which they were concatenated.
- *Discriminator* is the `type` property that tells which kind of question an object is.

**Schemas this plan binds.** Every property name below is exactly as it appears in `spec/openapi.json` under `components.schemas`.

- **`SystemOneRequest`** requires `model`, `state` and `questions`; `assets` is optional.
  - `model` is a string.
  - `state` is a string, object or array, never null, number or boolean.
  - `questions` is an object, with at least one property, mapping each question name to a `Question`.
  - `assets` is an object, with at least one property, mapping a placeholder string to an `Asset`. The Haskell field is a plain `Map Text Asset`; an empty map is omitted on encode, and an absent key decodes to `Map.empty`.
- **`Question`** is a `oneOf` with discriminator `type`, mapping `noul`, `choice`, `score` and `box` to the four schemas below.
- **`NoulQuestion`** requires `type`, which is the constant `"noul"`.
  - `instructions` is optional: string, object, array or null.
  - `criteria` is optional: a `NoulCriteria` or null.
- **`NoulCriteria`** has optional `true` and `false`, each a string, object, array or null.
- **`ChoiceQuestion`** requires `type` (`"choice"`) and `criteria`.
  - `instructions` is optional and nullable.
  - `criteria` is an object with 1 to 255 properties. Each value is a string, object, array or null, and the document says "a choice without a description is interpreted by its name alone".
- **`ScoreQuestion`** requires `type` (`"score"`) and `criteria`.
  - `instructions` is optional and nullable.
  - `criteria` is an array of 1 to 10 items. Each item is a string, object or array and is not nullable. An item's position is its score level, starting at zero.
- **`BoxQuestion`** requires `type` (`"box"`); `instructions` is optional and nullable.
- **`Asset`** has no required properties.
  - `type` is the constant `"image"`.
  - `format` is one of `"png"`, `"jpg"` or `"jpeg"`, and is required whenever `data_base64` is present (a rule stated only in prose).
  - `data_base64` is a string.
  - `part` is a string, used only by multipart requests. Those requests are excluded from this initiative and planned in [docs/plans/7-send-images-with-multipart-system-one-requests.md](7-send-images-with-multipart-system-one-requests.md). The field must still round-trip.

**Representation rules fixed by the MasterPlan.**

- *Field names.* Each record field takes the property's name verbatim. Snake case becomes lower camel case (`data_base64` becomes `dataBase64`), and no field carries a type-name prefix (R2). Because `DuplicateRecordFields` is on, several records may share a field named `instructions` or `criteria`.
- *No selector functions.* `NoFieldSelectors` is on, so no field becomes a top-level function: `TypeSafe.Wire` exports no `state`, `model`, `true` or `false` function to clash with mtl's `state` or a consumer's own names. Consumers read fields with `OverloadedRecordDot` (`q.instructions`), or with generic-lens (`q ^. #instructions`), which works because every type derives `Generic`. Record construction and pattern matching, including field puns, work as usual. Library and test code never use record-update syntax on these types; they construct new records instead.
- *Deriving and imports.* Every deriving clause names its strategy (`deriving stock (Generic, Eq, Show)`), because `DeriveAnyClass` is on. Qualified imports are postpositive (`import Data.Vector qualified as Vector`). Both conventions come from haskell-jitsurei: `mori://shinzui/haskell-jitsurei/docs/core-standards` and `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`. The library does not depend on `lens` or `generic-lens`.
- *The discriminator.* The `type` property is implied by the constructor, never stored as a field. On `Asset` it is implied by the type: written on encode, and accepted on decode when absent or equal to `"image"`.
- *Nullable positions.* `Content` has no null constructor, so positions where the schema allows null use `Maybe Content`, under these rules:
  - In a required-but-nullable slot, a choice-criteria map value, `Nothing` encodes as JSON `null`.
  - In an optional-and-nullable property (every `instructions`, noul `criteria`, and noul criteria's `true` and `false`), `Nothing` is omitted on encode. Both an absent key and an explicit `null` decode to `Nothing`.
  - Score criteria items are `NonEmpty Content`.
- *Both codec directions.* Every type has `ToJSON` with a hand-written `toEncoding` that agrees with `toJSON` up to key order, and `FromJSON`. EP-5's conformance suite checks decode-after-encode.
- *Unknown keys and tags.* Decoding ignores unknown properties on known objects. A `type` tag outside `noul`, `choice`, `score` and `box` decodes to `QuestionOther tag object`, which re-encodes the original object unchanged (R5's rule, applied here to questions).
- *Decoded order.* Because aeson objects do not preserve key order, the order of `questions` and of choice criteria after *decoding* is unspecified. Haddock comments must say so, as `docs/initial-spec.md` requires. Encoding order is always the `Vector` order.

**Reference implementation.** The community SDK's `TypeSafe.Wire` module solves similar encoding problems and is a useful idiom reference, though not a dependency. It lives at `mori://byteally/typesafe-sdk/packages/typesafe-ai-core`, project-relative path `typesafe-sdk/typesafe-ai-core/src/TypeSafe/Wire.hs` (artifact-level URI pending). Locate it on disk with `mori registry show byteally/typesafe-sdk --full`. Its `ChoiceQuestion` instance shows the order-preserving pattern:

```haskell
toEncoding q =
  pairs $
    ("type" .= ("choice" :: Text))
      <> optionalSeries "instructions" (choiceQuestionInstructions q)
      <> Encoding.pair "criteria" (pairs (foldMap (\(k, v) -> Key.fromText k .= v) (choiceQuestionCriteria q)))
```

That SDK uses prefixed field names and `Map QuestionId Question` for questions, which loses the caller's question order. Do not copy either choice.

**ADRs.** Read the ADRs EP-1 created under `docs/adr/` (scan the filenames). The one on the wire types mirroring the vendored specification records the naming, both-directions and unknown-tag rules summarised above. `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md` records which haskell-jitsurei conventions apply and why generic aeson, lens dependencies and a custom prelude are declined. No other local ADR applies. The cross-repository context is Baikai's boundary decisions: `mori://shinzui/baikai`, project-relative paths `docs/adr/0005-what-baikai-deliberately-does-not-do.md` and `docs/adr/0011-core-owns-transport-failure-classification.md` (artifact-level URIs pending). They only require that this module contain no policy; nothing here retries or classifies.


## Plan of Work

**Milestone 1: request types and codecs.** Create `src/TypeSafe/Wire/Request.hs`, exporting the types listed under Interfaces and Dependencies, and implement their codecs.

Declare every type with `deriving stock (Generic, Eq, Show)`; `ImageFormat` also derives `Enum` and `Bounded` in the same stock clause. Use postpositive qualified imports throughout, for example `import Data.Aeson.KeyMap qualified as KeyMap` and `import Data.Map.Strict qualified as Map`. Because `NoFieldSelectors` is on, instance code reads fields with record dot syntax (`req.questions`) or by pattern matching (`SystemOneRequest {model, state, questions, assets}`). It never applies a selector function.

Hand-write every `ToJSON` instance with both `toJSON` and `toEncoding`. The `toEncoding` side must use `pairs` and a `Series` in the fixed key order from the Decision Log, and must never call `toJSON` or go through `Value` (R3). Omit an optional field with a small local helper. For example, `optionalPair :: ToJSON a => Key -> Maybe a -> Series` returns `mempty` for `Nothing`.

Each container gets its own encoding:

- **Questions.** Encode `questions` with `Encoding.pair "questions" (pairs (foldMap (\(QuestionName k, q) -> Key.fromText k .= q) qs))`, so the `Vector` order is the wire order.
- **Choice criteria.** Use the same pattern, writing `Nothing` as `null` with `Key.fromText k .= v`, where `v :: Maybe Content` (aeson encodes `Nothing` as `null` in this position).
- **Score criteria.** Encode them as a JSON array of `Content`.
- **Content.** `Content`'s own `toEncoding`, from EP-1, writes objects and arrays by delegating to aeson's `Object` and `Array` encodings. Those order object keys by aeson's `KeyMap`, which is deterministic for a given value.
- **`QuestionOther tag obj`.** Encode `KeyMap.insert "type" (String tag) obj` through `toEncoding`, so the original object, including any fields this library does not model, goes out unchanged.
- **Assets.** Emit the `assets` pair only when `not (Map.null req.assets)`. Decode it with `.:?` and `fromMaybe Map.empty`.

Define `encodeSystemOneRequest = Data.Aeson.encodingToLazyByteString . toEncoding`. It is the same function aeson's `encode` applies, which is why EP-4's servant body will be byte-equal to it.

Write `FromJSON` instances with `withObject`:

- Check the discriminator with a helper that fails on a missing or wrong `type`. Each variant record (`NoulQuestion`, `ChoiceQuestion`, `ScoreQuestion`, `BoxQuestion`) owns its tag in both directions: its own `toEncoding` and `toJSON` write `"type"` first, and its own `FromJSON` requires it. `ToJSON Question` and `FromJSON Question` only dispatch to the variant instances. This matters because the specification marks `type` as required on each variant schema, and EP-5's conformance suite encodes and decodes the variant records on their own.
- Use `.:?` for optional-nullable fields, so absent and `null` both yield `Nothing`.
- Parse choice criteria with `traverse` over `KeyMap.toList`.
- Parse score criteria as `NonEmpty Content`, so an empty array fails.
- Dispatch `Question` on its `type` string to the four known parsers, falling back to `QuestionOther tag obj` with the whole object, including its `type` key.

Decide whether `QuestionOther` stores the object with or without `type`, document it in the Haddock comment, and make encode and decode agree. Storing it as received is simplest.

`ImageFormat` encodes to `"png"`, `"jpg"` or `"jpeg"` and fails to decode any other string. `Asset` decoding accepts a missing `type`, or `"image"`, and fails on any other value.

Add `duplicateQuestionNames` and `duplicateChoiceLabels`, then add the module to the library's `exposed-modules` in `typesafe-hs.cabal`. If EP-1 used a `cabal-gild: discover` pragma, the formatter does this. Finally, re-export the module from `src/TypeSafe/Wire.hs`.

Milestone 1 is accepted when `cabal build all` succeeds, and a GHCi session encodes a small request to the expected bytes (see Concrete Steps).

**Milestone 2: tests and goldens.** Add `test/TypeSafe/Wire/RequestTest.hs`, exporting `tests :: TestTree` as a tasty group named `TypeSafe.Wire.Request`. Register it in `test/Main.hs`, and list it in the test suite's `other-modules`.

Create the two golden files this plan owns:

- **`test/golden/baikai-request.json`** holds R11's request exactly as printed in `docs/initial-spec.md`, pretty-printed, for structural comparison.
- **`test/golden/baikai-request.bytes`** holds the exact compact encoding. The file must contain exactly these bytes, with no trailing newline:

```json
{"model":"jev-latest","state":{"ticket":"Checkout is unavailable."},"questions":{"urgent":{"type":"noul","instructions":"Is service blocked?"},"category":{"type":"choice","instructions":"Classify the issue.","criteria":{"billing":"Payment issue","technical":"Product malfunction"}},"severity":{"type":"score","instructions":"Rate impact.","criteria":["Minor","Disruptive","Blocking"]}}}
```

Write it with `printf '%s' '…' > test/golden/baikai-request.bytes`, so that no newline is appended. The repository's treefmt formatters (fourmolu, cabal-gild, nixpkgs-fmt) do not touch `.bytes` or `.json` files.

In the test module, build the fixture value in Haskell with record construction syntax, and read fields back with `OverloadedRecordDot` (for example `fixture.model`). That proves the plain field names work for a consumer under `NoFieldSelectors` (R2). Do not use record-update syntax: build each variant value afresh. Inline JSON inputs may use `MultilineStrings` (`"""` literals), which the test-suite stanza enables. The tests are:

1. **Structural golden (R11).** `decode` the output of `encodeSystemOneRequest fixture` and the contents of `baikai-request.json` into `Value`, and assert they are equal.
2. **Bytes golden (R3).** `encodeSystemOneRequest fixture` equals the contents of `baikai-request.bytes`.
3. **`encode` agrees.** `encode fixture` (aeson's) equals `encodeSystemOneRequest fixture`.
4. **Determinism.** Encoding the same value twice, and encoding an equal value built separately, give identical bytes.
5. **Declared order.** A request whose questions are declared `z`, `a`, `m` produces bytes in which `"z"` comes before `"a"` and `"a"` before `"m"`. A choice question with labels `technical`, `billing` keeps that order.
6. **Absent versus null (R3, R7).**
   - `instructions = Nothing` produces no `instructions` key.
   - Noul `criteria = Nothing` produces no `criteria` key.
   - `NoulCriteria { true = Just (ContentText "y"), false = Nothing }` encodes as `{"true":"y"}`.
   - A choice label with `Nothing` encodes as `"label":null`.
   - Decoding `{"type":"noul","instructions":null}` gives `instructions = Nothing`.
7. **Content is not stringified (R7).** A `state` of `ContentObject` and one of `ContentArray` encode as a JSON object and array. Decoding a request whose `state` is `42` or `null` fails.
8. **Unknown question type.** `{"type":"future","x":[1,2]}` decodes to `QuestionOther "future" obj`, and re-encodes to a value equal to the input.
9. **Empty assets are omitted (C6).** A request with `assets = Map.empty` encodes with no `assets` key: its bytes contain no `"assets"`. A request whose JSON has no `assets` key decodes to `assets == Map.empty`. A request with one asset encodes `"assets":{"photo":{"type":"image",...}}` after `questions`.
10. **Each variant decodes.** Decode each named request example under `paths."/v1/systemone".post.requestBody.content."application/json".examples` in `spec/openapi.json` (noul, choice, score and box, the last one with `assets` and `format: "png"`). Each is a `SystemOneRequest` with the expected constructor. Reading the file with `Data.Aeson.eitherDecodeFileStrict` is enough; there is no need for EP-5's schema machinery.
11. **Duplicates are reported, not collapsed.** A request with two questions named `a` reports `["a"]` from `duplicateQuestionNames`, and its bytes contain `"a":` twice. A choice question with repeated `billing` reports `["billing"]`.
12. **Required fields.** Decoding a choice question without `criteria`, a score question with `"criteria": []`, or a request without `state` fails.

Milestone 2 is accepted when `cabal test` reports the group passing, and each test fails when its expectation is deliberately broken. Check this once by temporarily swapping two keys in the `toEncoding` of `SystemOneRequest`: the bytes golden must fail.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/typesafe-hs`, inside the Nix development shell. Enter it with `nix develop`, or rely on `direnv`, which loads it through `.envrc`.

Build after Milestone 1:

```bash
cabal build all
```

Smoke-check the encoder interactively:

```bash
cabal repl typesafe-hs
```

```haskell
:set -XOverloadedStrings -XDuplicateRecordFields -XOverloadedRecordDot
import TypeSafe.Wire
import Data.Vector qualified as Vector
import Data.Map.Strict qualified as Map
encodeSystemOneRequest SystemOneRequest { model = jevLatest, state = ContentText "hi", questions = Vector.fromList [("b", QuestionBox BoxQuestion { instructions = Nothing })], assets = Map.empty }
```

```text
"{\"model\":\"jev-latest\",\"state\":\"hi\",\"questions\":{\"b\":{\"type\":\"box\"}}}"
```

Create the golden files during Milestone 2. The `.json` file is the pretty-printed R11 request; the `.bytes` file has no trailing newline:

```bash
mkdir -p test/golden
printf '%s' '{"model":"jev-latest","state":{"ticket":"Checkout is unavailable."},"questions":{"urgent":{"type":"noul","instructions":"Is service blocked?"},"category":{"type":"choice","instructions":"Classify the issue.","criteria":{"billing":"Payment issue","technical":"Product malfunction"}},"severity":{"type":"score","instructions":"Rate impact.","criteria":["Minor","Disruptive","Blocking"]}}}' > test/golden/baikai-request.bytes
tail -c 3 test/golden/baikai-request.bytes | od -c
```

```text
0000000   }   }   }
```

Run only this plan's tests, then the whole suite:

```bash
cabal test --test-show-details=direct --test-options='-p TypeSafe.Wire.Request'
cabal test
```

The expected tail of the output:

```text
  TypeSafe.Wire.Request
    golden request is structurally equal (R11):  OK
    golden request bytes are exact (R3):         OK
    ...
All N tests passed
```

Commit after each milestone, using a Conventional Commits message and the trailers:

```text
feat(wire): encode System One requests deterministically

MasterPlan: docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ExecPlan: docs/plans/2-encode-system-one-requests-deterministically.md
Intention: intention_01m5frxsb3e9et3b9mn8e31r8c
```


## Validation and Acceptance

The plan is accepted when all of the following hold:

1. `cabal build all` succeeds, and the new module adds no warnings under `-Wall`.
2. `cabal test` passes, including every test in the `TypeSafe.Wire.Request` group listed in Milestone 2.
3. `encodeSystemOneRequest` of the R11 fixture equals `test/golden/baikai-request.bytes` exactly. Swapping two keys in the request's `toEncoding` makes that test fail, which proves the test is not vacuous.
4. `TypeSafe.Wire` alone exports everything a consumer needs to build and encode a request. It exports no field-selector functions: in `cabal repl`, `:t state` resolves to nothing from `TypeSafe.Wire` (only `fixture.state` works).
5. Every type in `TypeSafe.Wire.Request` has an explicit-strategy `deriving stock (Generic, Eq, Show)` clause, and no file the plan adds uses a prepositive `import qualified`.

The byte-equality check that the same bytes leave through servant-client is EP-4's representative producer/consumer check, owned by [docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md). This plan makes it possible by routing aeson's `encode` through the same `toEncoding`. Schema-level conformance (every property encoded, required versus optional, discriminator tags) is EP-5's and is not required here.


## Idempotence and Recovery

Every step is additive and can be repeated:

- Re-running the `printf` overwrites the bytes golden with identical content.
- `cabal build` and `cabal test` are safe to repeat.
- If `nix fmt` or the pre-commit treefmt hook reformats the new Haskell modules, accept its output and re-run the tests.

If a golden file is accidentally given a trailing newline, the bytes test fails with a one-byte difference. Re-create the file with the `printf` above. Never regenerate the golden from the encoder's output to make a failing test pass. A mismatch means either the encoder's key order or the fixture is wrong, and must be diagnosed against R11.


## Interfaces and Dependencies

**Prerequisite.** [docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md](1-scaffold-the-package-and-vendor-the-system-one-specification.md) must be Complete. This is the parent MasterPlan's hard dependency, EP-1.

**Libraries.** This plan adds no new library dependencies beyond what EP-1 lists. In particular it adds no `lens` or `generic-lens`: `Generic` comes from `base`. It uses only these, from from R12's set: `aeson ^>=2.2`, `containers`, `text` and `vector`. `NonEmpty` comes from `base`. The test suite needs only `tasty`, `tasty-hunit`, `aeson`, `bytestring` and `vector`. If EP-1 did not already list one of these, add it to the test-suite stanza.

**Module.** `src/TypeSafe/Wire/Request.hs`, module `TypeSafe.Wire.Request`, defines the following. Every field is strict, and every type derives `Generic`, `Eq` and `Show` with an explicit `stock` strategy. Under `NoFieldSelectors` the fields are read with record dot syntax or generic-lens `#label`, never with selector functions.

```haskell
data SystemOneRequest = SystemOneRequest
  { model :: !ModelName,
    state :: !Content,
    questions :: !(Vector (QuestionName, Question)),
    assets :: !(Map Text Asset) -- omitted on the wire when empty
  }
  deriving stock (Generic, Eq, Show)

data Question
  = QuestionNoul !NoulQuestion
  | QuestionChoice !ChoiceQuestion
  | QuestionScore !ScoreQuestion
  | QuestionBox !BoxQuestion
  | QuestionOther !Text !Object -- tag, and the complete object as received
  deriving stock (Generic, Eq, Show)

data NoulQuestion = NoulQuestion
  { instructions :: !(Maybe Content),
    criteria :: !(Maybe NoulCriteria)
  }
  deriving stock (Generic, Eq, Show)

data NoulCriteria = NoulCriteria
  { true :: !(Maybe Content),
    false :: !(Maybe Content)
  }
  deriving stock (Generic, Eq, Show)

data ChoiceQuestion = ChoiceQuestion
  { instructions :: !(Maybe Content),
    criteria :: !(Vector (Text, Maybe Content))
  }
  deriving stock (Generic, Eq, Show)

data ScoreQuestion = ScoreQuestion
  { instructions :: !(Maybe Content),
    criteria :: !(NonEmpty Content)
  }
  deriving stock (Generic, Eq, Show)

newtype BoxQuestion = BoxQuestion {instructions :: Maybe Content}
  deriving stock (Generic, Eq, Show)

data ImageFormat = ImageFormatPng | ImageFormatJpg | ImageFormatJpeg
  deriving stock (Generic, Eq, Show, Enum, Bounded)

data Asset = Asset
  { format :: !(Maybe ImageFormat),
    dataBase64 :: !(Maybe Text),
    part :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

encodeSystemOneRequest :: SystemOneRequest -> Data.ByteString.Lazy.ByteString
duplicateQuestionNames :: SystemOneRequest -> [QuestionName]
duplicateChoiceLabels :: ChoiceQuestion -> [Text]
```

Every type above gets hand-written `ToJSON` and `FromJSON` instances, never `deriving anyclass` or generic aeson. `BoxQuestion` may be a `data` rather than a `newtype` if strictness or `DuplicateRecordFields` makes that simpler.

`src/TypeSafe/Wire.hs` adds `module TypeSafe.Wire.Request` to its export list. EP-4 consumes `SystemOneRequest`'s `ToJSON` instance in its servant `ReqBody '[JSON]`. EP-5 consumes all of these types and both codec directions, and binds the schema names `SystemOneRequest`, `Question`, `NoulQuestion`, `NoulCriteria`, `ChoiceQuestion`, `ScoreQuestion`, `BoxQuestion` and `Asset` to them.

Revision note (2026-10-21): aligned with the parent MasterPlan's haskell-jitsurei change set. The plan now uses postpositive imports and explicit `deriving stock (Generic, Eq, Show)` on every type, adopts `NoFieldSelectors` with record-dot-only access in the tests, and changes `assets` to a plain `Map Text Asset` that is omitted when empty, with a new test. The Decision Log records each change, and the old `assets` entry is marked superseded.
