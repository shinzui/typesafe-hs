---
id: 6
slug: prepare-the-first-hackage-release-of-typesafe-hs
title: "Prepare the first Hackage release of typesafe-hs"
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
      note: "Hackage's newest servant-client-core is 0.20.3.0, not 0.21.0.0 (that is the unreleased local checkout); http-client is listed unconditionally although EP-4 adds it only if needed"
---

# Prepare the first Hackage release of typesafe-hs

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this plan, anyone can add `typesafe-hs ^>=0.1` to a Cabal file and `cabal` will fetch it from Hackage, the public Haskell package archive at https://hackage.haskell.org. With it, they can encode System One requests, decode replies and call TypeSafe's API. Its documentation will be browsable on Hackage, and its README will show a working example.

The first consumer is the `baikai-typesafe` provider in another repository, planned in `mori://shinzui/baikai/plans/84-deliver-the-typesafe-system-one-provider-and-judgment-catalog`. Baikai's release gate builds every source distribution in an isolated project that resolves dependencies from Hackage only. A `source-repository-package` pin pointing at this git repository is acceptable to Baikai during development, but not for its release. So until `typesafe-hs` is on Hackage, `baikai-typesafe` cannot be released.

This plan turns the finished library into a release candidate and proves that candidate the way Baikai will consume it: from the source-distribution tarball, against Hackage alone, inside Baikai's dependency bounds. It then publishes the release, but only after the user explicitly confirms each outward-facing step.

You can see it working in three ways:

- The isolated consumer project in Milestone 2 builds and passes the test suite from the tarball.
- After Milestone 3, https://hackage.haskell.org/package/typesafe-hs shows version 0.1.0.0 with its documentation.
- `cabal info typesafe-hs` in any fresh project reports that version.


## Progress

- [ ] Milestone 1: the package is release-shaped. That means a license the user chose, complete Cabal metadata, `README.md` and `CHANGELOG.md`, a README example that is compiled and checked by the test suite, and 100% Haddock coverage of every exposed module. `cabal check` reports no errors or warnings, and `cabal sdist` produces `typesafe-hs-0.1.0.0.tar.gz` containing `spec/openapi.json` and the golden files.
- [ ] Milestone 2: the candidate is proven as a consumer will use it. The final bounds review is recorded. A scratch project outside the repository builds the tarball against Hackage only, with Baikai's bounds as constraints, and its test suite passes. `nix build` and `nix flake check` succeed in this repository.
- [ ] Milestone 3: the package is published. With the user's confirmation at each step, the name is re-verified as free, a package candidate and its documentation are uploaded and reviewed, the release is published, and the tag `v0.1.0.0` is created and pushed. The user is given a short note for Baikai's maintainers.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: the first release is version `0.1.0.0`, and its library dependency bounds are exactly the intervals listed under Interfaces and Dependencies, written with `^>=` where Baikai uses `^>=`.
  Rationale: under the Package Versioning Policy (PVP), Hackage's versioning convention, a major version has two components (`A.B`), so `0.1` is the first major version. The rest of the version is the minor and patch positions. Any bound that intersects Baikai's allows a joint build plan. Copying Baikai's own intervals is the simplest bound that always intersects and does not over-promise compatibility with untested majors.
  Date: 2026-10-21

- Decision: the license is not chosen by this plan. Milestone 1 stops and asks the user.
  Rationale: the repository has no `LICENSE` file, and the license is the owner's legal decision. Hackage requires one, and `cabal check` flags a missing license.
  Date: 2026-10-21

- Decision: the README example is kept as a real Haskell module in the test suite, and a test asserts that the README's code block is byte-equal to the marked region of that module. No `markdown-unlit` preprocessor is used.
  Rationale: this keeps the example compiling without adding a test-only build tool. When the two copies diverge, the failure is an ordinary test failure.
  Date: 2026-10-21

- Decision: the release follows the conventions adopted from haskell-jitsurei, recorded in `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`. The consequences for this plan are:
  - `-Werror=missing-fields` lives only in `cabal.project`. `typesafe-hs.cabal` carries no `-Werror` of any kind, so `cabal check` stays clean. The isolated consumer build uses its own `cabal.project`, so it never sees the flag and must not depend on it.
  - The README shows fields read with record dot syntax, because `NoFieldSelectors` means the package exports no selector functions. It also says that generic-lens `#label` access works through the `Generic` instance on every wire type, without this package depending on lens.
  - The bounds review includes `servant-client-core >=0.20.3 && <0.22` only if plan 4 added it as a direct library dependency.
  Rationale: a `-Werror` flag in a published Cabal file breaks consumers on newer compilers, and `cabal check` flags it. The README must describe the surface consumers actually get: record dot, `#label`, and no selectors.
  Date: 2026-10-21


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

This repository, `/Users/shinzui/Keikaku/bokuno/typesafe-hs` (registered in Mori as `mori://shinzui/typesafe-hs`, configured in `mori.dhall`), builds one Cabal package, `typesafe-hs`. Its requirements are R1 to R12 in [docs/initial-spec.md](../initial-spec.md). This plan implements R12, the packaging requirement. It is the last child of [docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md](../masterplans/1-deliver-the-initial-typesafe-hs-client.md).

**What exists when this plan starts.** Its hard prerequisites are the whole of [docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md) and [docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md). Both must be marked Complete in the MasterPlan's Exec-Plan Registry. Together with their own prerequisites, plans 1 to 3, they leave the working tree with these parts:

- `typesafe-hs.cabal` and `cabal.project` at the repository root.
  - The Cabal file has a common stanza: language `GHC2024`; extensions `DeriveAnyClass`, `DuplicateRecordFields`, `NoFieldSelectors`, `OverloadedLabels`, `OverloadedRecordDot` and `OverloadedStrings`; `ghc-options: -Wall`. The first four of those extensions are the haskell-jitsurei baseline (`mori://shinzui/haskell-jitsurei/docs/core-standards`).
  - The `library` uses `hs-source-dirs: src`. There is one `test-suite typesafe-hs-test` (tasty, `hs-source-dirs: test`, `main-is: Main.hs`), which also enables `MultilineStrings`.
  - `cabal.project` has a `package typesafe-hs` stanza with `ghc-options: -Werror=missing-fields`. That flag is for local development only and is never in the `.cabal` file.
- `spec/openapi.json`: the vendored OpenAPI document, `info.version` `0.2.0`, normalised with `jq -S .`. Next to it, `scripts/check-spec-drift.sh`, which reports whether the published document at https://api.typesafe.ai/openapi.json still matches the vendored copy.
- The umbrella module `src/TypeSafe/Wire.hs`, re-exporting these modules:
  - `TypeSafe.Wire.Common`: `apiSpecVersion`, `ModelName`, `QuestionName`, `jevLatest`, `jevPreview`, `Content` with `contentFromValue` and `contentToValue`, and the constants `requestIdHeader`, `dangerZoneImagesHeader`, `dangerZoneLongContextHeader`, `systemOnePath`, `modelsPath` and `defaultBaseUrl`.
  - `TypeSafe.Wire.Request`: `SystemOneRequest` (whose `assets` field is a plain `Map Text Asset`, omitted from the wire when empty), `Question` and its variants (noul, choice, score, box and the `QuestionOther` fallback), `NoulCriteria`, `Asset`, `encodeSystemOneRequest`, `duplicateQuestionNames` and `duplicateChoiceLabels`.
  - `TypeSafe.Wire.Response`: `SystemOneResponse`, `Answer` and its variants (including `AnswerOther`), `BoxCoordinates`, `Usage` (token counts are `Int`), `decodeSystemOneResponse`, and the helpers that convert `Scientific` numbers to `Double`.
  - `TypeSafe.Wire.Models`: `ModelMetadataList`, `ModelMetadata`, and a helper that parses the release day.
  - `TypeSafe.Wire.Error`: `ErrorBody`, `HTTPValidationError`, `ValidationError`, `LocationSegment` (whose index holds an `Int`) and `parseErrorBody`.
- Every exported wire type derives `Generic`, `Eq` and `Show` with explicit `deriving stock` or `deriving newtype` clauses. Because the common stanza enables `NoFieldSelectors`, the package exports no field selector functions. Consumers read fields with record dot syntax (`response.usage.inputTokens`), or with generic-lens `#label` access in their own code.
- `src/TypeSafe/V1.hs`, which enables `FieldSelectors` for itself. It exports:
  - the servant routes as a `NamedRoutes` record: `data Routes mode = Routes { systemOne, models }` with `type API = NamedRoutes Routes`, plus the endpoint synonyms `SystemOneEndpoint` and `ModelsEndpoint`;
  - the `Methods` record (`createSystemOne`, a variant that sets the danger-zone headers, and `listModels`);
  - `getClientEnv :: Text -> IO ClientEnv` and `makeMethods :: ClientEnv -> Text -> Methods`.
- Under `test/`:
  - golden files in `test/golden/`, including `baikai-request.json`, `baikai-request.bytes` and `baikai-response.json` with its negative variants;
  - a loopback mock-server test (`test/TypeSafe/Test/MockServer.hs`);
  - the conformance suite against `spec/openapi.json`;
  - QuickCheck generators in `test/TypeSafe/Test/Arbitrary.hs`.
- `docs/adr/`: the project's Architecture Decision Records, created by plan 1. Before starting, list the filenames. Two kinds of record matter here:
  - The record saying the library carries no transport policy (no retries, classification, timeouts, environment lookups or logging). The README must describe the library accordingly.
  - The record saying the first release targets the current published document with JSON bodies only and defers multipart upload to [docs/plans/7-send-images-with-multipart-system-one-requests.md](7-send-images-with-multipart-system-one-requests.md). The README and CHANGELOG must state that exclusion.
  - `docs/adr/0005-haskell-jitsurei-patterns-adopted-and-declined.md`, which records the haskell-jitsurei conventions this package follows and those it declines. It is what makes the README's field-access guidance and the `cabal.project`-only `-Werror` placement deliberate.

  No cross-repository ADR needs to be cited for packaging. Baikai's release-gate behaviour is described here from `docs/initial-spec.md` R12.

If any of these items are missing, the prerequisite plans are not complete. Stop and report it instead of filling the gap here.

**What does not exist yet**, and this plan adds: `LICENSE`, `README.md` and `CHANGELOG.md`; the release metadata in `typesafe-hs.cabal`; the README example test; and the release itself.

**Terms used in this plan:**

- *source distribution* (sdist): the `.tar.gz` that `cabal sdist` produces. It contains only the files the Cabal file declares, and it is exactly what Hackage serves, so a file missing from it is missing for every consumer.
- *package candidate*: an upload to Hackage that is visible at `https://hackage.haskell.org/package/typesafe-hs-0.1.0.0/candidate`, can be inspected and replaced, and is not yet in the index that `cabal` resolves from.
- *publishing*: makes the version permanent. Hackage never deletes a published version; it can only be deprecated.
- *Haddock*: the Haskell documentation generator. Its coverage line, for example `100% ( 42 / 42) in 'TypeSafe.Wire.Request'`, counts the exported items that carry documentation.

**Toolchain.** The dev shell comes from `flake.nix` and `nix/haskell.nix`, using GHC 9.12.4 (`pkgs.haskell.packages."ghc9124"`). Enter it with `direnv allow` once, or with `nix develop`. Every command below assumes that shell, run from the repository root unless a different directory is named. `nix build` builds `packages.default`, which is `callCabal2nix "typesafe-hs"` over this flake's source.

**Facts checked on 2026-10-21, to be re-checked in Milestone 2:**

- Baikai's Cabal files (`/Users/shinzui/Keikaku/bokuno/baikai/*/*.cabal`) declare `tested-with: ghc ==9.12.4` and these bounds: `aeson ^>=2.2`, `base >=4.20 && <5`, `bytestring ^>=0.12`, `containers ^>=0.7`, `scientific ^>=0.3`, `text ^>=2.1`, `vector ^>=0.13`, `http-types ^>=0.12`, `servant-client ^>=0.20`, `http-client ^>=0.7`, `http-client-tls >=0.3 && <0.5` and `time ^>=1.14`. Baikai declares no direct `servant` bound.
- Hackage's newest versions were `servant` 0.20.3.0, `servant-client` 0.20.3.0, `http-client` 0.7.19 and `http-client-tls` 0.4.0.
- `https://hackage.haskell.org/package/typesafe-hs` returned HTTP 404, so the name was free.


## Plan of Work

**Milestone 1: make the package release-shaped.**

1. **Choose the license.** First, stop and ask the user which license to publish under, for example BSD-3-Clause, MIT, Apache-2.0 or MPL-2.0, and who the copyright holder is. Use the `AskUserQuestion` tool in an agent session. Do not pick one. Record the answer in the Decision Log, then add the canonical text as `LICENSE` at the repository root.
2. **Complete the release metadata in `typesafe-hs.cabal`.** Set:
   - `version: 0.1.0.0`, and the `license` SPDX identifier with `license-file: LICENSE`;
   - `author` and `maintainer`, with the user's name and email address from `git config user.name` and `git config user.email`;
   - a one-line `synopsis` and a paragraph `description` (see Interfaces and Dependencies), and `category: AI, Web`;
   - `homepage: https://github.com/shinzui/typesafe-hs` and `bug-reports: https://github.com/shinzui/typesafe-hs/issues`;
   - a `source-repository head` stanza with `type: git` and `location: https://github.com/shinzui/typesafe-hs.git`;
   - `tested-with: GHC ==9.12.4`;
   - `extra-doc-files: README.md CHANGELOG.md`, and `extra-source-files` listing `spec/openapi.json`, `test/golden/*.json` and `test/golden/*.bytes`, so that the test suite can run from the source distribution;
   - no `-Werror` in any `ghc-options`, because `cabal check` rejects it in a published package. Confirm that `-Werror=missing-fields` appears only in `cabal.project`'s `package typesafe-hs` stanza. That file is not part of the source distribution, and Hackage consumers never read it.
3. **Write `README.md`.** It covers:
   - what the library is (wire types and codecs mirroring OpenAPI `0.2.0` as vendored, plus a servant client);
   - what it deliberately does not do (no retries, status classification, timeouts beyond the caller's `Manager`, environment lookups or logging; no multipart image upload in 0.1);
   - a short example;
   - how to check for specification drift with `scripts/check-spec-drift.sh`.

   The example does four things:
   - builds a one-question noul request with `jevLatest` and prints `encodeSystemOneRequest` of it;
   - shows the call path: `getClientEnv defaultBaseUrl`, then `makeMethods env apiKey`, then `createSystemOne`;
   - reads the answer and the token counts with record dot syntax, for example `response.usage.inputTokens`;
   - reads `apiKey` from `TYPESAFE_API_KEY` with `System.Environment.lookupEnv`. That is legitimate in an example and never in the library.

   Add a short "Field access" paragraph. It explains that the package enables `NoFieldSelectors`, so it exports no selector functions such as `state`, `model` or `left` that could clash with a consumer's names. Fields are read with record dot syntax. Because every wire type derives `Generic`, consumers who follow haskell-jitsurei's record pattern (`mori://shinzui/haskell-jitsurei/docs/core-record-patterns`) can use generic-lens `#label` access and updates in their own code, without this package depending on lens.
4. **Make the example a test.** Put the example's code in `test/TypeSafe/ReadmeExample.hs`, between the comment lines `-- README:BEGIN` and `-- README:END`. Add it to the test suite's `other-modules`. Add a tasty group "README example" to `test/Main.hs` with two tests:
   - the README's fenced `haskell` block between the HTML comments `<!-- README:BEGIN -->` and `<!-- README:END -->` is byte-equal to the module's marked region;
   - the pure part of the example equals expected literals: the encoded bytes, and a record-dot field read from a decoded inline response.

   The module compiling is the proof that the network part type-checks. It is never run, so the suite stays offline.
5. **Write `CHANGELOG.md`.** It has one entry, `## 0.1.0.0 — <release date>`, listing the surface above, the bound specification version and the multipart exclusion.
6. **Bring Haddock coverage to 100%.** Every exposed module gets a module header. Every exported item must carry documentation, and a doc comment that says nothing does not count. Fix any gaps until every exposed module reports 100%.

At the end of Milestone 1, `cabal check` is clean, `cabal test` passes (including the README group), and the source distribution contains the spec and the golden files.

**Milestone 2: prove the candidate as a consumer will use it.**

1. **Run the final bounds review.** Re-run the Hackage version queries and re-read Baikai's bounds (commands below). Include `servant-client-core` in the review only if `typesafe-hs.cabal`'s library stanza names it directly. Plan 4 adds it only if `TypeSafe.V1` imports from it. For every library dependency, confirm that our interval intersects Baikai's and includes the newest Hackage release in the same major version. Record the reviewed table in the Decision Log. If Baikai's bounds changed, follow Baikai.
2. **Build the tarball in isolation.** In a scratch directory outside the repository, create a `cabal.project` whose only package is the tarball, with `active-repositories: hackage.haskell.org` so that nothing resolves from this checkout. Add `constraints:` that mirror Baikai's bounds, then build and run the tests there.

   This is the producer/consumer check for the whole initiative. It reproduces Baikai's release gate without touching Baikai. The scratch `cabal.project` deliberately sets no `ghc-options`, so the build proves the package compiles without the repository's local `-Werror=missing-fields`.
3. **Check the Nix build.** Run `nix build` and `nix flake check` in the repository. `nix build` builds the package from nixpkgs' GHC 9.12.4 package set, and `nix flake check` runs the formatting and pre-commit checks configured in `nix/treefmt.nix` and `nix/pre-commit.nix`. If nixpkgs' `servant-client` falls outside our bounds, record it in Surprises & Discoveries. Fix it through `./flake.module.nix` (the unmanaged extension point; see `flake.module.nix.example`), never by editing `nix/haskell.nix`, which is managed by seihou, the project's template tool.

**Milestone 3: publish, with confirmation at each outward-facing step.** Each sub-step either publishes something or changes shared state, so get the user's explicit "yes" immediately before each one. A "yes" for the candidate does not cover publishing.

1. **Re-check that the name is free.** If it has been taken, stop and ask the user to choose a new name. A new name would also touch `mori.dhall`, `nix/haskell.nix` and the MasterPlan.
2. **Upload the candidate.** Upload the package candidate and its documentation. Ask the user to review the candidate page, including the rendered README, the module list and the documentation, and to confirm.
3. **Publish.** Publish the package and its documentation. Hackage authentication is interactive or token-based. When the agent cannot authenticate, ask the user to run the command with the `!` prefix so that its output lands in the session. A brand-new package needs a Hackage account with upload rights. If the upload is refused with a permissions error, tell the user; that is an account matter, not a packaging defect.
4. **Tag and push.** Create the annotated tag `v0.1.0.0` on the release commit. Push it only after confirmation.
5. **Hand off to Baikai.** Give the user a short note for Baikai's maintainers. It states that `typesafe-hs 0.1.0.0` is on Hackage, so the `source-repository-package` stanza used during development can be removed. It cites the provider plan `mori://shinzui/baikai/plans/84-deliver-the-typesafe-system-one-provider-and-judgment-catalog`, the requirements in `mori://shinzui/typesafe-hs` at project-relative path `docs/initial-spec.md` (artifact-level URI pending), and the Hackage URL. Do not edit the Baikai repository.

**After publishing.** Mark this plan Complete in the MasterPlan registry, then do the ADR distillation pass. The durable lesson is the release gate: a release candidate is proven from its source distribution against Hackage only, inside the first consumer's bounds, and every Hackage-visible step requires the owner's confirmation. If that lesson is not already recorded in `docs/adr/`, add it as a new record following the corpus convention (`docs/adr/NNNN-slug.md` with `title`, `status` and `date` frontmatter).


## Concrete Steps

**Milestone 1.** From the repository root, inside the dev shell:

```bash
cabal build all
cabal test all --test-show-details=direct
cabal check
grep -n 'Werror' typesafe-hs.cabal || echo 'no -Werror in typesafe-hs.cabal'
grep -n 'Werror=missing-fields' cabal.project
cabal haddock typesafe-hs --haddock-all 2>&1 | grep -E '^\s*[0-9]+% \('
cabal sdist
tar -tzf dist-newstyle/sdist/typesafe-hs-0.1.0.0.tar.gz | grep -E 'spec/openapi.json|test/golden/|LICENSE|README.md|CHANGELOG.md'
```

Expected: the test run ends with `All N tests passed`, and the README group is listed. The first `grep` prints `no -Werror in typesafe-hs.cabal`, and the second prints the `cabal.project` line. `cabal check` prints only its success line:

```text
No errors or warnings could be found in the package.
```

Every Haddock coverage line reads `100%`, for example:

```text
 100% (  9 /  9) in 'TypeSafe.Wire.Common'
 100% ( 31 / 31) in 'TypeSafe.Wire.Request'
```

The `tar` listing shows `typesafe-hs-0.1.0.0/spec/openapi.json`, every golden file, `LICENSE`, `README.md` and `CHANGELOG.md`.

**Milestone 2.** First, the bounds review queries, from any directory:

```bash
# add servant-client-core to this list only if typesafe-hs.cabal's library names it
for p in aeson servant servant-client http-client http-client-tls http-types scientific text vector containers bytestring time; do
  printf '%s: ' "$p"
  curl -fsS -H 'Accept: application/json' "https://hackage.haskell.org/package/$p/preferred" | jq -c '."normal-version"[:2]'
done
grep -hnE '^\s*(,\s*)?(aeson|base|bytestring|containers|scientific|text|vector|http-types|servant|servant-client|http-client|http-client-tls|time)\s' /Users/shinzui/Keikaku/bokuno/baikai/*/*.cabal | sort -u
```

Next, the isolated consumer build. The scratch directory is the session scratchpad when an agent runs this, or else a fresh `mktemp -d`, so it is never inside the repository:

```bash
SCRATCH="$(mktemp -d)/typesafe-hs-consumer"
mkdir -p "$SCRATCH"
cp /Users/shinzui/Keikaku/bokuno/typesafe-hs/dist-newstyle/sdist/typesafe-hs-0.1.0.0.tar.gz "$SCRATCH/"
cat > "$SCRATCH/cabal.project" <<'EOF'
packages: typesafe-hs-0.1.0.0.tar.gz
active-repositories: hackage.haskell.org
tests: True
constraints:
    aeson ^>=2.2
  , base >=4.20 && <5
  , bytestring ^>=0.12
  , containers ^>=0.7
  , scientific ^>=0.3
  , text ^>=2.1
  , vector ^>=0.13
  , http-types ^>=0.12
  , servant-client ^>=0.20
  , http-client ^>=0.7
  , http-client-tls >=0.3 && <0.5
  , time ^>=1.14
EOF
cd "$SCRATCH"
cabal update
cabal build all --enable-tests -w ghc-9.12.4
cabal test all --test-show-details=direct -w ghc-9.12.4
```

If `ghc-9.12.4` is not on `PATH` under that name, use `-w ghc` after `ghc --numeric-version` prints `9.12.4`. Expected: the build plan resolves without consulting this checkout; the output mentions only the tarball and Hackage packages. The tests end with `All N tests passed`, which proves that `spec/openapi.json` and the golden files travel in the tarball.

Finally, the Nix checks, back at the repository root:

```bash
nix build
nix flake check
```

Expected: both exit 0, and `./result` exists.

**Milestone 3.** Each block below runs only after the user has confirmed that step.

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://hackage.haskell.org/package/typesafe-hs
```

This should print `404`. Then build and upload the candidate:

```bash
cabal sdist
cabal haddock typesafe-hs --haddock-for-hackage
cabal upload dist-newstyle/sdist/typesafe-hs-0.1.0.0.tar.gz
cabal upload --documentation dist-newstyle/typesafe-hs-0.1.0.0-docs.tar.gz
```

The user reviews https://hackage.haskell.org/package/typesafe-hs-0.1.0.0/candidate. After a separate confirmation, publish:

```bash
cabal upload --publish dist-newstyle/sdist/typesafe-hs-0.1.0.0.tar.gz
cabal upload --publish --documentation dist-newstyle/typesafe-hs-0.1.0.0-docs.tar.gz
```

Then tag. After yet another confirmation, push the tag:

```bash
git tag -a v0.1.0.0 -m "typesafe-hs 0.1.0.0"
git push origin v0.1.0.0
```

**Commit messages.** Commits follow Conventional Commits and carry this plan's trailers, for example:

```text
chore(release): prepare typesafe-hs 0.1.0.0 metadata and docs

Add LICENSE, README, CHANGELOG and release metadata; compile the
README example in the test suite.

MasterPlan: docs/masterplans/1-deliver-the-initial-typesafe-hs-client.md
ExecPlan: docs/plans/6-prepare-the-first-hackage-release-of-typesafe-hs.md
Intention: intention_01m5frxsb3e9et3b9mn8e31r8c
```


## Validation and Acceptance

Milestone 1 is accepted when all of these hold:

- `cabal check` prints `No errors or warnings could be found in the package.`
- `typesafe-hs.cabal` contains no `-Werror`; `-Werror=missing-fields` appears only in `cabal.project`.
- The README documents record-dot field access, `#label` access through `Generic`, and the absence of exported selectors.
- `cabal test all` passes, including the "README example" group.
- **The README check catches drift.** Change one character inside the README's marked code block and the README group fails. Revert the change and it passes again.
- Every Haddock coverage line for an exposed module reads 100%.
- The sdist listing contains `spec/openapi.json` and every file in `test/golden/`.

Milestone 2 is accepted when all of these hold:

- The scratch project outside the repository builds and passes `cabal test all` from the tarball, with Hackage as the only repository and Baikai's bounds as constraints.
- The bounds table is recorded in the Decision Log.
- `nix build` and `nix flake check` exit 0.

This build is the initiative's consumer check: it reproduces Baikai's release gate. A failure here, for example a golden file missing from the tarball or an unsatisfiable bound, is a release blocker to fix in this plan.

Milestone 3 is accepted when all of these hold:

- `https://hackage.haskell.org/package/typesafe-hs` returns HTTP 200 and lists 0.1.0.0 with documentation.
- In a fresh scratch project, `cabal update && cabal info typesafe-hs` reports `Versions available: 0.1.0.0`.
- `git ls-remote --tags origin v0.1.0.0` shows the tag.
- The user has received the Baikai hand-off note.

Proposals that are not required for acceptance: CI that runs the isolated build on every push, and a widened `tested-with` covering GHC 9.6 to 9.14, which R12 calls desirable but not required.


## Idempotence and Recovery

Milestones 1 and 2 are safe to repeat. `cabal sdist` overwrites the tarball, and the scratch project lives in a fresh temporary directory each time. Delete it to start clean.

A Hackage package candidate can be re-uploaded with the same version until it is published, so a mistake found during the candidate review is fixed by editing, rebuilding the tarball and re-uploading.

Publishing is permanent: a published version cannot be deleted or replaced. If a defect is found after publishing, release `0.1.0.1` for a fix that keeps the API the same, or `0.2.0.0` for an API change. Ask the user whether to deprecate `0.1.0.0` through Hackage's maintainer page.

Hackage hosts documentation separately from the package and lets it be replaced, so the documentation can be re-uploaded with `cabal upload --publish --documentation`.

A local tag created by mistake is removed with `git tag -d v0.1.0.0`. Once a tag is pushed, it is shared state. Do not delete or move it without asking the user.


## Interfaces and Dependencies

**Hard prerequisites.** The whole of [docs/plans/4-bind-the-system-one-api-with-servant-and-servant-client.md](4-bind-the-system-one-api-with-servant-and-servant-client.md) and of [docs/plans/5-prove-conformance-with-the-vendored-openapi-document.md](5-prove-conformance-with-the-vendored-openapi-document.md) must be Complete. That is what makes the release candidate contain the full public surface listed under Context and Orientation, and pass the full suite.

**Public surface.** The released surface is exactly `TypeSafe.Wire`, its submodules (`TypeSafe.Wire.Common`, `.Request`, `.Response`, `.Models` and `.Error`) and `TypeSafe.V1`. This plan changes no type or function in them. A defect found in them during release is fixed under the owning plan's conventions, and is recorded here in Surprises & Discoveries.

**Library dependency bounds** for release 0.1.0.0. These intersect Baikai's bounds as of 2026-10-21 and must be re-checked in Milestone 2:

```text
aeson            ^>=2.2
base             >=4.20 && <5
bytestring       ^>=0.12
containers       ^>=0.7
scientific       ^>=0.3
text             ^>=2.1
vector           ^>=0.13
http-types       ^>=0.12
servant          ^>=0.20
servant-client   ^>=0.20
http-client      ^>=0.7
http-client-tls  >=0.3 && <0.5
time             ^>=1.14
```

If plan 4 also depends on `servant-client-core` directly, bound it `>=0.20.3 && <0.22`. That is the range `servant-client` 0.20.3.0 itself requires (its Cabal file says `servant-client-core >=0.20.3 && <0.22`), and Hackage's newest `servant-client-core` was 0.21.0.0 on 2026-10-21. Do not add the dependency only to review it.

**Test-suite dependencies** do not constrain consumers, so they only need to resolve on Hackage and with GHC 9.12.4. They are `tasty` and its add-ons, `QuickCheck`, `servant-server`, `warp` and `wai`. Give them caret bounds at their current major versions.

**Cabal metadata text** (wording may be refined):

```text
synopsis:    Wire types and a servant client for TypeSafe's System One API
description: Haskell types, deterministic request encoding and lossless response
             decoding for TypeSafe's System One API (POST /v1/systemone and
             GET /v1/models), mirroring the official OpenAPI document version 0.2.0,
             plus a servant API type and servant-client methods. The library adds no
             retries, failure classification, timeouts or environment lookups.
category:    AI, Web
```

**Tools:** `cabal` (cabal-install 3.12 or newer, from the dev shell), `curl` and `jq` for the Hackage queries, and Nix for `nix build` and `nix flake check`. Uploading needs a Hackage account with upload rights. The credentials belong to the user and are never written to the repository.

Revision note (2026-10-21): aligned with the haskell-jitsurei change set and the API idiom review. The surface summary now reflects the `NamedRoutes` `Routes` record, `NoFieldSelectors` with record-dot access, `Int` token counts, `assets` as a plain `Map` and `Generic` on every wire type. Milestones 1 and 2 now check that `-Werror=missing-fields` lives only in `cabal.project`, the README documents field access, and `servant-client-core` is bounded `>=0.20.3 && <0.22` only if it is a direct dependency.
