---
id: 1
slug: scaffold-the-package-and-vendor-the-system-one-specification
title: "Scaffold the package and vendor the System One specification"
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
    - model: "claude-fable-5-1"
      harness: "claude-code"
      at: 2026-10-22T03:32:09Z
      mode: "update"
      note: "ADR 0005 spec drops the FieldSelectors exception; cabal.project named as the only home for -Werror flags"
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-25T04:34:34Z
      mode: "implement"
      note: "Vendor approved current specification and implement scaffold, primitives and ADRs"
  reviews:
    - model: "claude-fable-5-1"
      harness: "claude-code"
      at: 2026-10-22T03:15:28Z
      verdict: "comments"
      note: "Live document, digest, schema list, toolchain and flake wiring all verified; no change needed"
---

# Scaffold the package and vendor the System One specification

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository is meant to hold `typesafe-hs`, a Haskell library for TypeSafe's System One API at `https://api.typesafe.ai`. Today it holds only a Nix development shell and a written specification, [docs/initial-spec.md](../initial-spec.md). There is no Cabal package, no copy of the API's machine-readable description, and no tests. This plan creates the foundation that every later plan in [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md) builds on.

After this plan, a contributor can do four things that were not possible before:

1. **Build and test the library.** `cabal build` and `cabal test` work in this directory, and so does `nix build` (which runs the tests too). The library exports the small set of types and constants that both the request side and the response side of the API need. The main one is `Content`, the union of "a JSON string, object or array" that the API accepts as the content being judged (the "state") and as question instructions.
2. **Read the vendored API description.** The official OpenAPI document is checked in at `spec/openapi.json`. OpenAPI is a JSON format that describes every endpoint, request body and response body of an HTTP API.
3. **Check for drift.** Running `scripts/check-spec-drift.sh` reports whether the copy published by TypeSafe has changed since it was vendored.
4. **Read the project's design decisions.** They are recorded as Architecture Decision Records (ADRs) under `docs/adr/`. An ADR is a short Markdown file that records one design decision, its context and its consequences, so that later readers know why the code is shaped the way it is.

You can see it working when `cabal test` prints its tests passing. They prove that `Content` refuses numbers, booleans and `null`, that it round-trips strings, objects and arrays, and that the library's `apiSpecVersion` constant equals the vendored document's `info.version`.


## Progress

- [x] Milestone 1 (2026-10-24; drift script exit 0 against the approved 21-schema baseline): `spec/openapi.json` is vendored, normalised and tracked, and `scripts/check-spec-drift.sh` reports the vendored copy current (exit 0).
- [x] Milestone 2 (2026-10-24; 13 tests pass with GHC 9.12.4, Cabal and Nix): the `typesafe-hs` package builds with the haskell-jitsurei baseline common stanza plus `NoFieldSelectors` and `OverloadedRecordDot`. `TypeSafe.Wire.Common` and the umbrella `TypeSafe.Wire` export the shared primitives, each deriving `Generic` with explicit strategies, and `cabal test` and `nix build` both pass the `Content` codec tests and the `apiSpecVersion` test.
- [x] Milestone 3 (2026-10-24; five ADRs and index, nix fmt and nix flake check pass): `docs/adr/` holds records 0001 to 0005 and an index, and formatting (`nix fmt`) and `nix flake check` are clean.


## Surprises & Discoveries

- **2026-10-24 baseline update, approved by the user.** The freshly fetched document still reports `0.2.0`, but now has 21 schemas: `HTTPBadRequestError` was added, with required `detail` accepting a string or arbitrary object. Both endpoints now document HTTP 400 using it. The normalized SHA-256 is `14bfe394955d2f31dfb653a1b18dd561c8da4d12677915a10fcc8c62e0fcbcc3`. EP-3 owns its wire codec; EP-5 binds the additional schema and HTTP 400 response references. JSON-only request scope and raw `ClientError` behavior remain the accepted design.


## Decision Log

- Decision: header-name constants have type `Network.HTTP.Types.HeaderName` (from `http-types`). Path constants are `[Text]` segments, and `defaultBaseUrl` is `Text`.
  Rationale: `HeaderName` is what servant-client and http-client consume, so neither EP-4 nor Baikai has to convert. `http-types` is already in R1's dependency list. Path segments as `[Text]` match how servant lays out a route, and are trivially joined with `/` by a consumer making its own http-client call.
  Date: 2026-10-21

- Decision: `scripts/check-spec-drift.sh` only reports by default. It rewrites `spec/openapi.json` only when given the explicit `--write` flag.
  Rationale: the MasterPlan forbids silently re-vendoring the document. Any change to it must be a deliberate, reviewed commit, because it can invalidate the conformance suite owned by EP-5.
  Date: 2026-10-21

- Decision: the package follows the haskell-jitsurei core standards (`mori://shinzui/haskell-jitsurei/docs/core-standards`) and record patterns (`mori://shinzui/haskell-jitsurei/docs/core-record-patterns`), with recorded exceptions:
  - **Common stanza.** It is the jitsurei baseline (`GHC2024`; `DeriveAnyClass`, `DuplicateRecordFields`, `OverloadedLabels`, `OverloadedStrings`) plus `NoFieldSelectors` and `OverloadedRecordDot`, with `ghc-options: -Wall`.
  - **Imports and deriving.** Qualified imports are postpositive. Every deriving clause names its strategy, and every exported type derives `Generic`.
  - **Test-only extension.** `MultilineStrings` is enabled only in the test suite.
  - **Local warnings.** `-Werror=missing-fields`, together with the stricter warning flags, lives in `cabal.project` rather than in the `.cabal` file.
  - **ADR 0005.** It records which jitsurei patterns are adopted and which are declined.

  Rationale:
  - **Consistency.** These are the fleet's minimum conventions, and Baikai's consumers follow them.
  - **`NoFieldSelectors`.** It keeps the umbrella module from exporting top-level functions such as `state`, `model`, `left` or `right` that clash with mtl, `Control.Arrow` and users' own names. Fields stay readable with record dot syntax, and with generic-lens `#label` through `Generic`.
  - **Warnings in `cabal.project`.** `-Werror` flags in a published `.cabal` file make `cabal check` complain, and break Hackage users on newer compilers. Putting them in `cabal.project` keeps them fatal for local development only.
  - **Declined patterns.** The library cannot take `lens` or `generic-lens` as dependencies, because of R1's dependency list, and its JSON encoders must stay hand-written for R3. ADR 0005 records these declined patterns so they are not re-proposed.

  Date: 2026-10-21


## Outcomes & Retrospective

The foundation is complete. Cabal and Nix both pass 13 tests; REPL confirms the umbrella exports Content and Generic. Drift exits 0/1/2 and version mismatch, missing-file and corrupt-file failures were exercised and restored. The user approved the 21-schema baseline, whose content digest is recorded above. nix fmt normalized existing whitespace in nix/haskell.nix without changing behavior. ADR dates reflect implementation on 2026-10-24 rather than the original planned date.


## Context and Orientation

### Where this plan sits

This is child plan EP-1 of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md). It has no dependencies. The plans that depend on it, and what each takes from it, are:

- [docs/plans/2-encode-system-one-requests-deterministically.md](2-encode-system-one-requests-deterministically.md) (EP-2) and [docs/plans/3-decode-system-one-responses-model-listings-and-error-bodies.md](3-decode-system-one-responses-model-listings-and-error-bodies.md) (EP-3) consume the primitives defined here. They add their own modules to the Cabal file, to the umbrella module and to the test tree.
- [docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md) (EP-4) uses the constants.
- [docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md) (EP-5) reads `spec/openapi.json`.
- [docs/plans/6-prepare-the-first-hackage-release-of-typesafe-hs.md](6-prepare-the-first-hackage-release-of-typesafe-hs.md) (EP-6) finalises the package metadata.

You do not need to read those plans to implement this one. What they expect from it is stated below.

### What exists in the working tree

The repository root is `/Users/shinzui/Keikaku/bokuno/typesafe-hs`. The relevant files are:

- **`flake.nix`, `nix/haskell.nix`, `nix/treefmt.nix`, `nix/pre-commit.nix`.** A seihou-managed Nix flake. "seihou-managed" means a scaffolding tool generated these files and will overwrite edits to them, so do not edit them.
  - `nix/haskell.nix` builds the root package with `final.callCabal2nix "typesafe-hs" inputs.self { }`. This means the Cabal file must be at the repository root and named `typesafe-hs.cabal`, and the package name must be `typesafe-hs`.
  - The flake's `devShells.default` provides GHC 9.12.4 and cabal-install 3.16.1.0. Verified on 2026-10-21 with `nix develop -c ghc --numeric-version`.
  - Formatting is wired through treefmt: `nix fmt` runs `fourmolu` on Haskell files (configured by `fourmolu.yaml`: two-space indent, trailing commas and arrows), `cabal-gild` on `*.cabal` and `cabal.project`, and `nixpkgs-fmt` on Nix files. `cabal-gild` is not on the dev shell's `PATH`, so always format with `nix fmt` rather than calling the tools directly.
  - A pre-commit hook installed by the dev shell runs the same treefmt check on commit.
- **`.envrc`.** `use flake`, so with direnv the dev shell loads automatically on entering the directory. Without direnv, prefix commands with `nix develop -c`.
- **`.gitignore`.** Already ignores `dist-newstyle` (through `dist-*`), `cabal.project.local` and `result`.
- **`docs/initial-spec.md`.** The specification, with requirements R1 to R12. This plan serves:
  - **R7:** the `Content` union and its helpers;
  - **R8:** the open name newtypes and model constants;
  - **R6:** the pure constants;
  - **R10:** the vendored document, `apiSpecVersion` and the drift script;
  - **R12:** the package skeleton.

  Read R1, R6, R7, R8, R10 and R12 before starting.
- **`docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md`.** The coordinating plan. Its Integration Points section fixes the exact names this plan must create; they are repeated under Interfaces and Dependencies below.
- **`mori.dhall`.** Registers this project as `mori://shinzui/typesafe-hs`, with one Haskell library package at path `.`. It declares no OKF document bundle, so `docs/adr/` follows a plain filesystem convention, not an OKF profile (see Milestone 3).

There is no `docs/adr/` directory yet. No local ADR exists to cite.

### Two cross-repository decisions that shape R1

Both come from the sibling Baikai project, `mori://shinzui/baikai`, the first consumer of this library.

- **What Baikai deliberately does not do.** Project-relative path `docs/adr/0005-what-baikai-deliberately-does-not-do.md`. Baikai classifies whether a failure is retryable, but never retries.
- **Core owns transport failure classification.** Project-relative path `docs/adr/0011-core-owns-transport-failure-classification.md`. Baikai's core, not any provider dependency, turns transport exceptions and statuses into categories.

Mori's concept registry had no artifact-level handle for either record on 2026-10-21, so cite them by the project URI plus the project-relative path and say the artifact-level URI is pending. Together they are why this library must contain no retry, classification, timeout or environment policy. ADR 0002 below records that.

### The haskell-jitsurei conventions this package follows

`mori://shinzui/haskell-jitsurei` (local checkout `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei`) is the catalogue of Haskell conventions shared across this owner's projects. Three of its documents apply here:

- **Core standards, `mori://shinzui/haskell-jitsurei/docs/core-standards` (`patterns/core/standards.md`).**
  - Every package uses `GHC2024` and a `common` stanza with at least `DeriveAnyClass`, `DuplicateRecordFields`, `OverloadedLabels` and `OverloadedStrings`. Projects may add to this baseline but not relax it.
  - Qualified imports are postpositive (`import Data.Vector qualified as Vector`), never `import qualified Data.Vector as Vector`.
- **Record patterns, `mori://shinzui/haskell-jitsurei/docs/core-record-patterns` (`patterns/core/record-patterns.md`).**
  - Fields carry no prefixes and are strict.
  - Every deriving clause names its strategy (`deriving stock`, `deriving newtype`, `deriving anyclass`), because `DeriveAnyClass` is on, and a clause without a strategy can silently derive an empty instance.
  - Records derive `Generic`, so that code can read and update them with generic-lens `#label` syntax.
- **Multiline strings, `mori://shinzui/haskell-jitsurei/docs/core-multiline-strings` (`patterns/core/multiline-strings.md`).** `MultilineStrings` (GHC 9.12 and later) gives indentation-stripped `"""…"""` literals. Here it is enabled only in the test suite, for inline JSON.

This project adds two extensions to the baseline:

- **`OverloadedRecordDot`,** which R2 requires: consumers read fields as `answer.confidence`.
- **`NoFieldSelectors`.** It stops GHC from generating a top-level selector function for each record field. Without it, the wire modules would export functions named `state`, `model`, `name`, `left`, `right` and so on, which clash with mtl, `Control.Arrow` and users' own code. With it, fields are still usable in record construction, in pattern matching and through `HasField`. That means record dot syntax works, and so does generic-lens `#label` through `Generic`. The library itself does not depend on `lens` or `generic-lens`.

The types this plan defines (`Content` and the two newtypes) have no record fields, so `NoFieldSelectors` changes nothing in them; it is set here so that EP-2 and EP-3 inherit it. The jitsurei patterns this library deliberately does not adopt are recorded in ADR 0005 (Milestone 3):

- `MultiVerb` error statuses;
- a custom prelude;
- `lens` and `generic-lens` as library dependencies;
- shared generic aeson options;
- the server-side API patterns.

### The OpenAPI document and its drift

TypeSafe publishes its OpenAPI document at `https://api.typesafe.ai/openapi.json`. On 2026-10-21 that document had:

- `openapi` 3.1.0 and `info.version` `0.2.0`;
- the paths `/v1/models` and `/v1/systemone`;
- 21 component schemas (current approved baseline): `Answer`, `Asset`, `BoxAnswer`, `BoxCoordinates`, `BoxQuestion`, `ChoiceAnswer`, `ChoiceQuestion`, `HTTPBadRequestError`, `HTTPValidationError`, `ModelMetadata`, `ModelMetadataList`, `NoulAnswer`, `NoulCriteria`, `NoulQuestion`, `Question`, `ScoreAnswer`, `ScoreQuestion`, `SystemOneRequest`, `SystemOneResponse`, `Usage` and `ValidationError`.

Once normalised with `jq -S .`, the copy fetched that day was a normalized SHA-256 of `14bfe394955d2f31dfb653a1b18dd561c8da4d12677915a10fcc8c62e0fcbcc3` (2026-10-24). `jq -S .` re-indents the JSON and sorts every object's keys, so the file is stable to diff.

That document is a superset of the older copy `docs/initial-spec.md` was written against. The older copy is vendored by the community SDK at `mori://byteally/typesafe-sdk/packages/typesafe-ai-core`, project-relative path `typesafe-sdk/typesafe-ai-core/spec/openapi.json` (artifact-level URI pending). Both copies say `0.2.0`. Because the version label did not change when the content did, the drift script must compare content, not version strings.

The user decided on 2026-10-21 that the first release targets the current published document, with JSON request bodies only. The `multipart/form-data` request body (images sent as separate parts) is deferred to [docs/plans/7-send-images-with-multipart-system-one-requests.md](7-send-images-with-multipart-system-one-requests.md), which is outside the MasterPlan. ADR 0004 below records that.

### An aeson detail that later plans rely on

aeson 2.2's `Object` is a `KeyMap Value`, backed by default by an ordered `Data.Map`. Encoding an `Object` therefore writes its keys in sorted order, which is deterministic. `Content`'s `toEncoding` must delegate to aeson's own `toEncoding` for `Object` and `Array`, and must never go through `show` or an intermediate string. EP-2's byte-determinism guarantee (R3) for a caller's `state` rests on this.


## Plan of Work

The work has three milestones. Each is independently verifiable and leaves the repository in a working state.

### Milestone 1: vendor the specification and the drift script

Create `spec/openapi.json` by fetching the published document and normalising it with `jq -S .`. Always re-fetch. Do not copy any other local file, because the published document may have moved since this plan was written. Compare the fetched document's `info.version` and schema list with the facts in Context and Orientation:

- **If they match,** continue.
- **If they differ** (a new version string, or a schema added or removed), stop. Record the difference in this plan's Surprises & Discoveries and in the MasterPlan's Surprises & Discoveries, and ask for a decision before continuing. Every later plan uses the 21-schema baseline approved on 2026-10-24.
- **If only the SHA-256 differs** but the version and schema list match, record the new digest in Surprises & Discoveries and continue.

Write `scripts/check-spec-drift.sh`. It is a POSIX `sh` script (or `bash` with `set -euo pipefail`) that does five things:

1. Fetches `${TYPESAFE_OPENAPI_URL:-https://api.typesafe.ai/openapi.json}` with `curl -fsS --max-time 30` into a temporary file, removed on exit with `trap`.
2. Normalises both that file and `spec/openapi.json` with `jq -S .`.
3. Compares the two with `diff -u`.
4. Exits with one of these codes:
   - **0,** printing `spec/openapi.json is current (info.version <v>)`, when the two are identical;
   - **1,** printing the unified diff followed by `spec/openapi.json has drifted from <url>`, when they differ;
   - **2,** printing a message to standard error, when `curl` or `jq` is missing, the fetch fails, or either file is not valid JSON.
5. With the explicit flag `--write`, after reporting drift, overwrites `spec/openapi.json` with the normalised published copy and exits 0. Without `--write` it never modifies the repository.

The script resolves `spec/openapi.json` relative to the repository root (`"$(dirname "$0")/.."`), so it works from any directory. Make it executable (`chmod +x`).

### Milestone 2: the package, the shared primitives and the test harness

This milestone creates five files. The exact exports are under Interfaces and Dependencies.

1. **`typesafe-hs.cabal`, at the repository root.** It contains:
   - **Package header:** `cabal-version: 3.12`, `name: typesafe-hs`, `version: 0.1.0.0`, a one-line `synopsis`, `category: AI, Web`, `build-type: Simple`, `tested-with: GHC ==9.12.4` and `extra-source-files: spec/openapi.json`. The last one ensures that a source distribution carries the document the tests read; EP-6 relies on that. Leave `license`, `author`, `maintainer` and the long `description` to EP-6, which owns release metadata and must ask the user which license to use.
   - **`common common`:** exactly the following. It is the haskell-jitsurei baseline plus `NoFieldSelectors` and `OverloadedRecordDot` (see Context and Orientation):

     ```cabal
     common common
       default-language: GHC2024
       default-extensions:
         DeriveAnyClass
         DuplicateRecordFields
         NoFieldSelectors
         OverloadedLabels
         OverloadedRecordDot
         OverloadedStrings
       ghc-options: -Wall
     ```

     Cabal recognises `GHC2024` only with `cabal-version: 3.12` or later. If `cabal check` or cabal2nix rejects it, fall back to `default-language: GHC2021` plus `DataKinds`, `DerivingStrategies`, `ImportQualifiedPost` and `LambdaCase` alongside the six extensions above, and record the fallback in the Decision Log.
   - **`library`:** `import: common`, `hs-source-dirs: src`, and `exposed-modules: TypeSafe.Wire, TypeSafe.Wire.Common`. Its dependencies are `aeson ^>=2.2`, `base >=4.20 && <5`, `http-types ^>=0.12` and `text ^>=2.1`. Every bound here is copied from R12 so that it intersects Baikai's. Later plans add `bytestring`, `containers`, `scientific`, `vector`, `servant` and `servant-client` when they first need them. `GHC.Generics` comes from `base`, so deriving `Generic` adds no dependency.
   - **`test-suite typesafe-hs-test`:**
     - `import: common`, plus `default-extensions: MultilineStrings` in the stanza itself, so tests can embed JSON fixtures as `"""…"""` literals.
     - `type: exitcode-stdio-1.0`, `hs-source-dirs: test`, `main-is: Main.hs`.
     - `other-modules: TypeSafe.SpecVersionTest, TypeSafe.Wire.CommonTest`.
     - `ghc-options: -threaded -rtsopts -with-rtsopts=-N`.
     - Dependencies: `typesafe-hs`, `aeson`, `base`, `bytestring ^>=0.12`, `text`, `vector ^>=0.13`, `tasty >=1.4 && <1.6` and `tasty-hunit ^>=0.10`.

     Test-only packages may use bounds outside R12's list, because Baikai never builds this test suite.
2. **`cabal.project`:** `packages: .`, `tests: True`, and a package stanza that makes missing record fields fatal and turns on the stricter warnings for local development only:

   ```cabal
   packages: .
   tests: True

   package typesafe-hs
     ghc-options: -Werror=missing-fields -Wcompat -Widentities -Wincomplete-record-updates -Wincomplete-uni-patterns -Wmissing-deriving-strategies -Wredundant-constraints
   ```

   These flags do not go in `typesafe-hs.cabal`. A `-Werror` flag in a published `.cabal` file makes `cabal check` complain, and turns a new warning in a future GHC into a build failure for Hackage users. `-Wmissing-deriving-strategies` enforces the jitsurei rule that every deriving clause names its strategy. `nix build` reads only the `.cabal` file, so under Nix these flags are simply absent. A later plan that needs another `-Werror=` flag adds it to this stanza, never to `typesafe-hs.cabal`; EP-5 adds `-Werror=incomplete-patterns` here.
3. **`src/TypeSafe/Wire/Common.hs`:** the primitives. `Content`'s instances are written by hand:
   - `toJSON` maps each constructor to the corresponding `Value`.
   - `toEncoding` uses `toEncoding` on the underlying `Text`, `Object` or `Array`.
   - `parseJSON` accepts `String`, `Object` and `Array`, and fails on `Number`, `Bool` and `Null` with a message naming the JSON kind it got, for example `expected a string, object or array, got number`. Those are the three kinds the specification's `x-accepts: "string | object | array"` annotation allows.
   - `contentFromValue` is the total, `Maybe`-returning version of `parseJSON`; `contentToValue` is `toJSON`.

   Each export gets a single-line Haddock comment that cites its R-number.

   Follow the jitsurei conventions in this and every other module:
   - Write qualified imports postpositively, for example `import Data.Text qualified as Text` and `import Data.Aeson.KeyMap qualified as KeyMap`.
   - Name every deriving strategy: `Content` uses `deriving stock (Generic, Eq, Show)`. Each newtype uses `deriving stock (Generic, Show)` and `deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)`.
   - Never derive JSON instances with `anyclass` or generic aeson. `Content`'s instances are hand-written so that EP-2 controls the exact bytes (R3).
4. **`src/TypeSafe/Wire.hs`:** the umbrella module. It re-exports the whole of `TypeSafe.Wire.Common` with `module TypeSafe.Wire.Common`. Add a module Haddock comment saying that consumers import only `TypeSafe.Wire`, and that EP-2 and EP-3 will add re-exports of `TypeSafe.Wire.Request`, `TypeSafe.Wire.Response`, `TypeSafe.Wire.Models` and `TypeSafe.Wire.Error`.
5. **The test files:**
   - **`test/Main.hs`** builds the tasty tree, `defaultMain (testGroup "typesafe-hs" [TypeSafe.SpecVersionTest.tests, TypeSafe.Wire.CommonTest.tests])`. Each later plan adds exactly one entry to this list.
   - **`test/TypeSafe/SpecVersionTest.hs`** reads `spec/openapi.json`, a path relative to the package directory, which is the working directory under both `cabal test` and `nix build`. It decodes the file with aeson and asserts that `info.version` equals `apiSpecVersion`. If the file is missing or malformed the test must fail, not be skipped.
   - **`test/TypeSafe/Wire/CommonTest.hs`** holds HUnit cases for `Content` and the name newtypes, covering:
     - `decode "\"hi\""` gives `ContentText "hi"`;
     - an object and an array decode to `ContentObject` and `ContentArray`;
     - `decode` of `1`, `true` and `null` each fail (`Nothing` from `decode`, or `Left` from `eitherDecode` with the message mentioning the kind);
     - `contentFromValue (Number 1)`, `(Bool True)` and `Null` are `Nothing`;
     - `contentToValue <$> contentFromValue v == Just v` for a string, a nested object and an array;
     - `encode c == encode (contentToValue c)`, showing that `toEncoding` agrees with `toJSON`;
     - a nested object such as `{"b":1,"a":{"d":2,"c":3}}` encodes with keys in sorted order on every run;
     - `encode (ModelName "jev-latest") == "\"jev-latest\""`;
     - `"x" :: QuestionName` type-checks, showing `IsString` works;
     - every constant has the value listed below.

     Write multi-line JSON inputs as `MultilineStrings` literals rather than `unlines` lists or escaped one-liners.

The package must build with zero warnings under the common stanza and the `cabal.project` flags above. Run `nix fmt` before committing. `nix build` builds from the flake's own source, which contains only files tracked by git, so `git add` every new file before running it.

### Milestone 3: the ADR corpus and repository checks

Create `docs/adr/` following the plain filesystem convention used by Baikai (`mori://shinzui/baikai`, project-relative path `docs/adr/0001-architecture-decision-record-convention.md`, artifact-level URI pending). In that convention, each record is one Markdown file named `NNNN-kebab-case-slug.md`, numbered from `0001` and never renumbered. Its YAML frontmatter has exactly `title`, `status` (`accepted`, `superseded` or `rejected`) and `date`. Its body has the sections Context, Decision and Consequences. Records are never deleted; a superseded record keeps its file, changes its status and names its replacement.

Write six files:

- **`docs/adr/0001-architecture-decision-record-convention.md`.** Records the convention just described. Context: `mori.dhall` declares no OKF bundle, so there is no profile to validate against. Consequences: adopting the shared OKF ADR profile later is separate, deliberate work.
- **`docs/adr/0002-the-library-carries-no-transport-policy.md`.** The library contains no retry loop, no mapping of statuses or exceptions to categories or retryability, no timeout policy beyond the caller's `Manager`, no reading of credentials or base URLs from the environment, and no logging hook. A `getClientEnv :: Text -> IO ClientEnv` convenience is allowed. Failures from `makeMethods` are servant-client's `ClientError`, unmodified. Cite R1 and the two Baikai records above. Name the community SDK's client layer (`mori://byteally/typesafe-sdk`) as the rejected alternative that bundled retries, timeouts, credential lookup and classification.
- **`docs/adr/0003-wire-types-mirror-the-vendored-specification.md`.** Covers:
  - one Haskell type per schema in `spec/openapi.json`;
  - field names taken verbatim from properties, with snake case turned into lower camel case (`input_tokens` becomes `inputTokens`) and `type` becoming `type_`;
  - `DuplicateRecordFields` with `OverloadedRecordDot`, not prefixes. `NoFieldSelectors` means fields are read with record dot syntax or generic-lens `#label`, so the wire modules export no top-level selector functions;
  - `deriving stock (Generic, Eq, Show)` on every wire type, with explicit strategies, so consumers can use generic-lens without the library depending on it;
  - integral counts (`Usage` token counts, `ValidationError` location indices) as `Int`, decoded from a `Scientific` that must be integral and fit an `Int`, never through aeson's truncating `Integer` instance;
  - discriminated unions as sum types whose constructors imply the tag, with an explicit `…Other tag object` constructor for unknown tags;
  - `ToJSON` (with a `toEncoding` that agrees with `toJSON`) and `FromJSON` for every wire type;
  - probabilities, confidences and scores as `Scientific`;
  - decoders that accept exactly what the schema accepts and perform no semantic validation;
  - unknown additional properties ignored on decode;
  - the null-handling rule: `Content` has no null; optional-and-nullable properties use `Maybe Content` where `Nothing` is omitted on encode and both absent and `null` decode to `Nothing`; required-but-nullable choice-criteria values encode `Nothing` as `null`.

  Cite R2, R4, R5 and R7. This record is the durable home of the MasterPlan's codec conventions; EP-2, EP-3 and EP-5 update it if they change them.
- **`docs/adr/0004-the-first-release-targets-the-published-document-with-json-bodies-only.md`.** Records the drift discovered on 2026-10-21 (same `0.2.0` label, added schemas) and the user's choice to bind every schema of the current published document but only its `application/json` request body. The two `TypeSafe-Danger-Zone-*` headers are bound in the servant API. Images travel inline through `Asset.data_base64`. Multipart is deferred to [docs/plans/7-send-images-with-multipart-system-one-requests.md](../plans/7-send-images-with-multipart-system-one-requests.md) because it needs `servant-multipart-api` and `servant-multipart-client`, outside R1's dependency list. Consequence: EP-5's conformance suite must name the multipart content type as an explicit, tested exclusion rather than silently ignore it.
- **`docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`.** Records which haskell-jitsurei patterns this library follows, citing `mori://shinzui/haskell-jitsurei/docs/core-standards`, `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`, `mori://shinzui/haskell-jitsurei/docs/core-multiline-strings` and `mori://shinzui/haskell-jitsurei/docs/api-servant-routes`.
  - **Adopted from the core standards and record patterns:**
    - the baseline common stanza, plus `NoFieldSelectors` and `OverloadedRecordDot`;
    - postpositive qualified imports;
    - explicit deriving strategies;
    - `Generic` on every wire type;
    - strict, unprefixed fields;
    - `MultilineStrings` in tests;
    - `-Werror=missing-fields` for local development, set in `cabal.project`.
  - **Adopted from servant-routes, by EP-4:**
    - `NamedRoutes` instead of a positional `:<|>` chain;
    - the auth header on each route field;
    - route fields read with record dot syntax like every other record, because `HasField` resolves a `NamedRoutes` field's `(:-)` type once the mode is concrete (verified on 2026-10-21 with GHC 9.12.4 and servant 0.20.3.0); no module re-enables `FieldSelectors`.
  - **Declined, each with its reason:**
    - *`MultiVerb` with declared error statuses.* R1 requires failures to surface as servant-client's unmodified `ClientError`, and the server's status set is not ours to declare: 400, 401 and 429 are observed but undocumented.
    - *A custom `TypeSafe.Prelude`.* It would add public surface to a roughly six-module Hackage package, and its lens re-export exceeds R1's dependency list.
    - *`lens` and `generic-lens` as library dependencies, and lens-based internal updates.* R1 limits the dependencies, and the library constructs records rather than updating them. Consumers still get `#label` through `Generic`.
    - *Shared generic aeson options.* R3 needs hand-written `toEncoding` with fixed key orders, plus project-specific rules for absent versus null, variant-owned tags and `Vector`-of-pairs objects.
    - *The server-side API patterns* (OpenAPI from types, RFC 9457 problem details, health endpoints, request logging, OpenTelemetry, Relay pagination, Hurl). This library consumes a third-party API; the vendored document, not one derived from our types, is the contract.
  - **Consequence:** a later proposal to adopt a declined pattern must supersede this record.
- **`docs/adr/README.md`.** A one-paragraph explanation of the convention and a bullet list linking each record with its title.

Links inside ADRs to plans and to `docs/initial-spec.md` are repository-relative. Links to other repositories use `mori://` URIs as above.

Finally run `nix fmt` and `nix flake check`. `nix flake check` runs the treefmt check and builds the package with its tests. Both must be clean.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/typesafe-hs`, inside the dev shell. If direnv is active, the shell is already loaded; otherwise prefix each command with `nix develop -c`.

Milestone 1:

```bash
mkdir -p spec scripts
curl -fsS --max-time 30 https://api.typesafe.ai/openapi.json | jq -S . > spec/openapi.json
jq -r '.info.version, (.components.schemas | keys | length), (.paths | keys | join(" "))' spec/openapi.json
shasum -a 256 spec/openapi.json
```

Expected output as of 2026-10-21 (the digest may change; see Plan of Work):

```text
0.2.0
20
/v1/models /v1/systemone
9a1f5d01bac7c4e55d20db1cf8e79aa879977ab9d610766e0eaedd6c45f68ae0  spec/openapi.json
```

After writing the script:

```bash
chmod +x scripts/check-spec-drift.sh
scripts/check-spec-drift.sh; echo "exit=$?"
TYPESAFE_OPENAPI_URL=https://api.typesafe.ai/does-not-exist scripts/check-spec-drift.sh; echo "exit=$?"
cp spec/openapi.json "$TMPDIR/openapi.json.bak"
jq '.info.version = "9.9.9"' "$TMPDIR/openapi.json.bak" > spec/openapi.json
scripts/check-spec-drift.sh; echo "exit=$?"
cp "$TMPDIR/openapi.json.bak" spec/openapi.json
```

Expected, in order: `spec/openapi.json is current (info.version 0.2.0)` and `exit=0`; an error on standard error and `exit=2`; a diff mentioning `9.9.9`, the drift message and `exit=1`. The last command restores the file. Confirm with `git diff --stat spec/openapi.json`, which should print nothing once the file is tracked.

Milestone 2:

```bash
cabal update
cabal build all
cabal test all --test-show-details=direct
```

Expected tail of the test output, with one line per case:

```text
typesafe-hs
  spec version
    apiSpecVersion matches spec/openapi.json info.version: OK
  TypeSafe.Wire.Common
    Content decodes a string:                               OK
    ...
All N tests passed (0.00s)
```

Then confirm that a broken test fails. Temporarily change `apiSpecVersion` to `"0.0.0"`, run `cabal test`, see the version test fail with both values printed, and restore it. Then:

```bash
git add typesafe-hs.cabal cabal.project src test spec scripts
nix build -L
```

`nix build` must finish without error and leave a `result` symlink. Its log includes the test-suite run, because the Nix Haskell builder runs tests by default.

Milestone 3:

```bash
nix fmt
git status --short
nix flake check -L
```

`nix fmt` may reformat files. Inspect the changes, keep them, and run `nix flake check` again until it exits 0.

Commit at the end of each milestone with a Conventional Commits message and both trailers, for example:

```text
feat(wire): add the package skeleton and shared wire primitives

Add typesafe-hs.cabal, the TypeSafe.Wire.Common primitives (Content,
name newtypes, constants, apiSpecVersion) and the tasty test suite.

MasterPlan: docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ExecPlan: docs/plans/1-scaffold-the-package-and-vendor-the-system-one-specification.md
Intention: intention_01m5frxsb3e9et3b9mn8e31r8c
```


## Validation and Acceptance

The plan is accepted when all of the following hold, observed on a clean checkout of the final commit:

1. `scripts/check-spec-drift.sh` exits 0 and prints the current message. Against a modified copy it exits 1 with a diff. With an unreachable URL it exits 2. `spec/openapi.json` is tracked and normalised: `jq -S . spec/openapi.json | diff - spec/openapi.json` prints nothing.
2. `cabal build all` succeeds with no warnings, and `cabal test all` passes every case listed in Milestone 2. Changing `apiSpecVersion` makes the version test fail, and so does deleting or corrupting `spec/openapi.json`. Each of these is checked once by hand and then reverted.
3. In `cabal repl typesafe-hs`, `:t Data.Aeson.decode @TypeSafe.Wire.Content "1"` type-checks and evaluates to `Nothing`, and `TypeSafe.Wire.contentFromValue (Data.Aeson.String "x")` evaluates to `Just (ContentText "x")`. This shows the umbrella module exports the primitives.
4. `nix build` and `nix flake check` succeed.
5. The jitsurei conventions hold:
   - `grep -rn 'import qualified' src test` prints nothing, because every qualified import is postpositive;
   - `cabal build all` under the `cabal.project` flags reports no `-Wmissing-deriving-strategies` warning;
   - in `cabal repl typesafe-hs`, `:i TypeSafe.Wire.Content` lists a `Generic` instance.
6. `docs/adr/` contains 0001 to 0005 and `README.md`, each record with `title`, `status: accepted` and `date: 2026-10-21` frontmatter and Context, Decision and Consequences sections, and every relative link resolves. Check with `ls` and by opening each linked path.


## Idempotence and Recovery

Every step is safe to repeat.

- **Re-vendoring.** Re-running the fetch overwrites `spec/openapi.json` with the same normalised bytes unless the published document changed. If it did change, `git diff spec/openapi.json` shows exactly what moved, and the decision rule in Milestone 1 applies.
- **The drift script** never writes without `--write`.
- **`cabal build`** can be re-run freely. If dependency resolution fails, run `cabal update` and retry. If it still fails on a bound, record the conflicting version in Surprises & Discoveries rather than widening an R12 bound, because those bounds must intersect Baikai's.
- **`nix build`** failing with "file not found" for a new module or for `spec/openapi.json` almost always means the file is not yet `git add`ed. Nix copies only tracked files into the build.
- **Generated state.** To discard build output, delete `dist-newstyle/` and `result`. Both are ignored by git.


## Interfaces and Dependencies

At the end of this plan, `src/TypeSafe/Wire/Common.hs` exports exactly the following. Later plans depend on these names and types; changing one requires updating the MasterPlan's Integration Points.

```haskell
module TypeSafe.Wire.Common
  ( apiSpecVersion,
    ModelName (..),
    QuestionName (..),
    jevLatest,
    jevPreview,
    Content (..),
    contentFromValue,
    contentToValue,
    requestIdHeader,
    dangerZoneImagesHeader,
    dangerZoneLongContextHeader,
    systemOnePath,
    modelsPath,
    defaultBaseUrl,
  )
where

import Data.Aeson (Array, FromJSON, FromJSONKey, Object, ToJSON, ToJSONKey, Value)
import Data.String (IsString)
import Data.Text (Text)
import GHC.Generics (Generic)
import Network.HTTP.Types (HeaderName)

-- | The OpenAPI @info.version@ of spec/openapi.json (R10).
apiSpecVersion :: Text
apiSpecVersion = "0.2.0"

-- | A model name or alias; any value the API accepts is representable (R8).
newtype ModelName = ModelName Text
  deriving stock (Generic, Show)
  deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

-- | A caller-chosen question name, used to key answers (R8).
newtype QuestionName = QuestionName Text
  deriving stock (Generic, Show)
  deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

jevLatest, jevPreview :: ModelName
jevLatest = "jev-latest"
jevPreview = "jev-preview"

-- | The specification's "string | object | array" union (R7); never null.
data Content
  = ContentText !Text
  | ContentObject !Object
  | ContentArray !Array
  deriving stock (Generic, Eq, Show)

-- instance ToJSON Content   -- toJSON and toEncoding, hand-written
-- instance FromJSON Content -- rejects Number, Bool and Null

contentFromValue :: Value -> Maybe Content
contentToValue :: Content -> Value

requestIdHeader :: HeaderName              -- "x-typesafe-request-id"
dangerZoneImagesHeader :: HeaderName       -- "TypeSafe-Danger-Zone-Images"
dangerZoneLongContextHeader :: HeaderName  -- "TypeSafe-Danger-Zone-Long-Context"
systemOnePath :: [Text]                    -- ["v1", "systemone"]
modelsPath :: [Text]                       -- ["v1", "models"]
defaultBaseUrl :: Text                     -- "https://api.typesafe.ai"
```

`src/TypeSafe/Wire.hs` is `module TypeSafe.Wire (module TypeSafe.Wire.Common) where import TypeSafe.Wire.Common`.

Every later module inherits the common stanza: `GHC2024` with `DeriveAnyClass`, `DuplicateRecordFields`, `NoFieldSelectors`, `OverloadedLabels`, `OverloadedRecordDot` and `OverloadedStrings`. Later plans must therefore:
- read fields with record dot syntax;
- name every deriving strategy, deriving `Generic` on each wire type;
- write postpositive qualified imports;
- construct records rather than using record update syntax on wire types.

No module re-enables `FieldSelectors`; `TypeSafe.V1` (EP-4) reads its `NamedRoutes` record with record dot syntax like any other record.

Library dependencies after this plan are `aeson ^>=2.2`, `base >=4.20 && <5`, `http-types ^>=0.12` and `text ^>=2.1`, all from R12. The test suite also uses `bytestring`, `vector`, `tasty` and `tasty-hunit`, and enables `MultilineStrings`.

The shared files this plan creates, and how later plans extend them, are listed in the MasterPlan's Integration Points:

- **`typesafe-hs.cabal`:** later plans add modules and dependencies.
- **`src/TypeSafe/Wire.hs`:** later plans add re-exports.
- **`test/Main.hs`:** each later plan adds one tasty group.
- **`spec/openapi.json`:** no other plan edits it; drift is a decision for the MasterPlan.
- **`docs/adr/`:** later plans update a record when they change its decision, and add new records numbered from `0006`.
- **`cabal.project`:** its `package typesafe-hs` stanza holds the development-only warning flags, to which EP-5 adds `-Werror=incomplete-patterns`; EP-6 confirms none of them leak into `typesafe-hs.cabal`.


Revision note (2026-10-21): aligned the plan with the haskell-jitsurei conventions (`mori://shinzui/haskell-jitsurei/docs/core-standards`, `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`) and the idiom review of the planned API:
- **Common stanza.** It is now the jitsurei baseline plus `NoFieldSelectors` and `OverloadedRecordDot`, with `MultilineStrings` in the test suite.
- **Warning flags.** `-Werror=missing-fields` and the stricter warnings moved into `cabal.project`.
- **Instances and imports.** `Generic`, with explicit deriving strategies, is now on the shared types, and qualified imports are postpositive.
- **ADRs.** ADR 0003 now covers `Generic`, `NoFieldSelectors` and `Int` counts, and ADR 0005 is added for the adopted and declined jitsurei patterns.

The change avoids exporting selector functions that clash with common names, lets consumers use generic-lens on the wire types, and matches the conventions of the owner's other Haskell projects.

Revision note (2026-10-22): after the MasterPlan review, ADR 0005's servant-routes bullet no longer records a `FieldSelectors` exception for `TypeSafe.V1`, because record dot syntax was verified to resolve `NamedRoutes` fields, and the `cabal.project` stanza is named as the only home for `-Werror=` flags, including EP-5's `-Werror=incomplete-patterns`.
