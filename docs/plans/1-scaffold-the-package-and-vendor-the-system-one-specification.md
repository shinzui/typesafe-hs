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

- [ ] Milestone 1: `spec/openapi.json` is vendored, normalised and tracked, and `scripts/check-spec-drift.sh` reports the vendored copy current (exit 0).
- [ ] Milestone 2: the `typesafe-hs` package builds. `TypeSafe.Wire.Common` and the umbrella `TypeSafe.Wire` export the shared primitives, and `cabal test` and `nix build` both pass the `Content` codec tests and the `apiSpecVersion` test.
- [ ] Milestone 3: `docs/adr/` holds records 0001 to 0004 and an index, and formatting (`nix fmt`) and `nix flake check` are clean.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: header-name constants have type `Network.HTTP.Types.HeaderName` (from `http-types`). Path constants are `[Text]` segments, and `defaultBaseUrl` is `Text`.
  Rationale: `HeaderName` is what servant-client and http-client consume, so neither EP-4 nor Baikai has to convert. `http-types` is already in R1's dependency list. Path segments as `[Text]` match how servant lays out a route, and are trivially joined with `/` by a consumer making its own http-client call.
  Date: 2026-10-21

- Decision: `scripts/check-spec-drift.sh` only reports by default. It rewrites `spec/openapi.json` only when given the explicit `--write` flag.
  Rationale: the MasterPlan forbids silently re-vendoring the document. Any change to it must be a deliberate, reviewed commit, because it can invalidate the conformance suite owned by EP-5.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


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

### The OpenAPI document and its drift

TypeSafe publishes its OpenAPI document at `https://api.typesafe.ai/openapi.json`. On 2026-10-21 that document had:

- `openapi` 3.1.0 and `info.version` `0.2.0`;
- the paths `/v1/models` and `/v1/systemone`;
- 20 component schemas: `Answer`, `Asset`, `BoxAnswer`, `BoxCoordinates`, `BoxQuestion`, `ChoiceAnswer`, `ChoiceQuestion`, `HTTPValidationError`, `ModelMetadata`, `ModelMetadataList`, `NoulAnswer`, `NoulCriteria`, `NoulQuestion`, `Question`, `ScoreAnswer`, `ScoreQuestion`, `SystemOneRequest`, `SystemOneResponse`, `Usage` and `ValidationError`.

Once normalised with `jq -S .`, the copy fetched that day was 1280 lines with SHA-256 `9a1f5d01bac7c4e55d20db1cf8e79aa879977ab9d610766e0eaedd6c45f68ae0`. `jq -S .` re-indents the JSON and sorts every object's keys, so the file is stable to diff.

That document is a superset of the older copy `docs/initial-spec.md` was written against. The older copy is vendored by the community SDK at `mori://byteally/typesafe-sdk/packages/typesafe-ai-core`, project-relative path `typesafe-sdk/typesafe-ai-core/spec/openapi.json` (artifact-level URI pending). Both copies say `0.2.0`. Because the version label did not change when the content did, the drift script must compare content, not version strings.

The user decided on 2026-10-21 that the first release targets the current published document, with JSON request bodies only. The `multipart/form-data` request body (images sent as separate parts) is deferred to [docs/plans/7-send-images-with-multipart-system-one-requests.md](7-send-images-with-multipart-system-one-requests.md), which is outside the MasterPlan. ADR 0004 below records that.

### An aeson detail that later plans rely on

aeson 2.2's `Object` is a `KeyMap Value`, backed by default by an ordered `Data.Map`. Encoding an `Object` therefore writes its keys in sorted order, which is deterministic. `Content`'s `toEncoding` must delegate to aeson's own `toEncoding` for `Object` and `Array`, and must never go through `show` or an intermediate string. EP-2's byte-determinism guarantee (R3) for a caller's `state` rests on this.


## Plan of Work

The work has three milestones. Each is independently verifiable and leaves the repository in a working state.

### Milestone 1: vendor the specification and the drift script

Create `spec/openapi.json` by fetching the published document and normalising it with `jq -S .`. Always re-fetch. Do not copy any other local file, because the published document may have moved since this plan was written. Compare the fetched document's `info.version` and schema list with the facts in Context and Orientation:

- **If they match,** continue.
- **If they differ** (a new version string, or a schema added or removed), stop. Record the difference in this plan's Surprises & Discoveries and in the MasterPlan's Surprises & Discoveries, and ask for a decision before continuing. Every later plan assumes the 20 schemas listed above.
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
   - **`common common`:** `default-language: GHC2024`, `default-extensions: DuplicateRecordFields, OverloadedRecordDot, OverloadedStrings`, and `ghc-options: -Wall -Wcompat -Widentities -Wincomplete-record-updates -Wincomplete-uni-patterns -Wmissing-deriving-strategies -Wredundant-constraints`. Cabal recognises `GHC2024` only with `cabal-version: 3.12` or later. If `cabal check` or cabal2nix rejects it, fall back to `default-language: GHC2021` plus `default-extensions: DataKinds, DerivingStrategies, LambdaCase` alongside the three above, and record the fallback in the Decision Log.
   - **`library`:** `import: common`, `hs-source-dirs: src`, and `exposed-modules: TypeSafe.Wire, TypeSafe.Wire.Common`. Its dependencies are `aeson ^>=2.2`, `base >=4.20 && <5`, `http-types ^>=0.12` and `text ^>=2.1`. Every bound here is copied from R12 so that it intersects Baikai's. Later plans add `bytestring`, `containers`, `scientific`, `vector`, `servant` and `servant-client` when they first need them.
   - **`test-suite typesafe-hs-test`:** `import: common`, `type: exitcode-stdio-1.0`, `hs-source-dirs: test`, `main-is: Main.hs`, `other-modules: TypeSafe.SpecVersionTest, TypeSafe.Wire.CommonTest`, and `ghc-options: -threaded -rtsopts -with-rtsopts=-N`. Its dependencies are `typesafe-hs`, `aeson`, `base`, `bytestring ^>=0.12`, `text`, `vector ^>=0.13`, `tasty >=1.4 && <1.6` and `tasty-hunit ^>=0.10`. Test-only packages may use bounds outside R12's list, because Baikai never builds this test suite.
2. **`cabal.project`:** `packages: .` and `tests: True`.
3. **`src/TypeSafe/Wire/Common.hs`:** the primitives. `Content`'s instances are written by hand:
   - `toJSON` maps each constructor to the corresponding `Value`.
   - `toEncoding` uses `toEncoding` on the underlying `Text`, `Object` or `Array`.
   - `parseJSON` accepts `String`, `Object` and `Array`, and fails on `Number`, `Bool` and `Null` with a message naming the JSON kind it got, for example `expected a string, object or array, got number`. Those are the three kinds the specification's `x-accepts: "string | object | array"` annotation allows.
   - `contentFromValue` is the total, `Maybe`-returning version of `parseJSON`; `contentToValue` is `toJSON`.

   Each export gets a single-line Haddock comment that cites its R-number.
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

The package must build with zero warnings under the flags above. Run `nix fmt` before committing. `nix build` builds from the flake's own source, which contains only files tracked by git, so `git add` every new file before running it.

### Milestone 3: the ADR corpus and repository checks

Create `docs/adr/` following the plain filesystem convention used by Baikai (`mori://shinzui/baikai`, project-relative path `docs/adr/0001-architecture-decision-record-convention.md`, artifact-level URI pending). In that convention, each record is one Markdown file named `NNNN-kebab-case-slug.md`, numbered from `0001` and never renumbered. Its YAML frontmatter has exactly `title`, `status` (`accepted`, `superseded` or `rejected`) and `date`. Its body has the sections Context, Decision and Consequences. Records are never deleted; a superseded record keeps its file, changes its status and names its replacement.

Write five files:

- **`docs/adr/0001-architecture-decision-record-convention.md`.** Records the convention just described. Context: `mori.dhall` declares no OKF bundle, so there is no profile to validate against. Consequences: adopting the shared OKF ADR profile later is separate, deliberate work.
- **`docs/adr/0002-the-library-carries-no-transport-policy.md`.** The library contains no retry loop, no mapping of statuses or exceptions to categories or retryability, no timeout policy beyond the caller's `Manager`, no reading of credentials or base URLs from the environment, and no logging hook. A `getClientEnv :: Text -> IO ClientEnv` convenience is allowed. Failures from `makeMethods` are servant-client's `ClientError`, unmodified. Cite R1 and the two Baikai records above. Name the community SDK's client layer (`mori://byteally/typesafe-sdk`) as the rejected alternative that bundled retries, timeouts, credential lookup and classification.
- **`docs/adr/0003-wire-types-mirror-the-vendored-specification.md`.** Covers:
  - one Haskell type per schema in `spec/openapi.json`;
  - field names taken verbatim from properties, with snake case turned into lower camel case (`input_tokens` becomes `inputTokens`) and `type` becoming `type_`;
  - `DuplicateRecordFields` with `OverloadedRecordDot`, not prefixes;
  - discriminated unions as sum types whose constructors imply the tag, with an explicit `…Other tag object` constructor for unknown tags;
  - `ToJSON` (with a `toEncoding` that agrees with `toJSON`) and `FromJSON` for every wire type;
  - probabilities, confidences and scores as `Scientific`;
  - decoders that accept exactly what the schema accepts and perform no semantic validation;
  - unknown additional properties ignored on decode;
  - the null-handling rule: `Content` has no null; optional-and-nullable properties use `Maybe Content` where `Nothing` is omitted on encode and both absent and `null` decode to `Nothing`; required-but-nullable choice-criteria values encode `Nothing` as `null`.

  Cite R2, R4, R5 and R7. This record is the durable home of the MasterPlan's codec conventions; EP-2, EP-3 and EP-5 update it if they change them.
- **`docs/adr/0004-the-first-release-targets-the-published-document-with-json-bodies-only.md`.** Records the drift discovered on 2026-10-21 (same `0.2.0` label, added schemas) and the user's choice to bind every schema of the current published document but only its `application/json` request body. The two `TypeSafe-Danger-Zone-*` headers are bound in the servant API. Images travel inline through `Asset.data_base64`. Multipart is deferred to [docs/plans/7-send-images-with-multipart-system-one-requests.md](../plans/7-send-images-with-multipart-system-one-requests.md) because it needs `servant-multipart-api` and `servant-multipart-client`, outside R1's dependency list. Consequence: EP-5's conformance suite must name the multipart content type as an explicit, tested exclusion rather than silently ignore it.
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
5. `docs/adr/` contains 0001 to 0004 and `README.md`, each record with `title`, `status: accepted` and `date: 2026-10-21` frontmatter and Context, Decision and Consequences sections, and every relative link resolves. Check with `ls` and by opening each linked path.


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
import Network.HTTP.Types (HeaderName)

-- | The OpenAPI @info.version@ of spec/openapi.json (R10).
apiSpecVersion :: Text
apiSpecVersion = "0.2.0"

-- | A model name or alias; any value the API accepts is representable (R8).
newtype ModelName = ModelName Text
  deriving stock (Show)
  deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

-- | A caller-chosen question name, used to key answers (R8).
newtype QuestionName = QuestionName Text
  deriving stock (Show)
  deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

jevLatest, jevPreview :: ModelName
jevLatest = "jev-latest"
jevPreview = "jev-preview"

-- | The specification's "string | object | array" union (R7); never null.
data Content
  = ContentText !Text
  | ContentObject !Object
  | ContentArray !Array
  deriving stock (Eq, Show)

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

Library dependencies after this plan are `aeson ^>=2.2`, `base >=4.20 && <5`, `http-types ^>=0.12` and `text ^>=2.1`, all from R12. The test suite also uses `bytestring`, `vector`, `tasty` and `tasty-hunit`.

The shared files this plan creates, and how later plans extend them, are listed in the MasterPlan's Integration Points:

- **`typesafe-hs.cabal`:** later plans add modules and dependencies.
- **`src/TypeSafe/Wire.hs`:** later plans add re-exports.
- **`test/Main.hs`:** each later plan adds one tasty group.
- **`spec/openapi.json`:** no other plan edits it; drift is a decision for the MasterPlan.
- **`docs/adr/`:** later plans update a record when they change its decision, and add new records numbered from `0005`.
