---
name: release
description: Release the typesafe-hs package to Hackage following PVP
argument-hint: "[major|minor|patch]"
disable-model-invocation: true
allowed-tools: Read, Bash, Edit, Glob, Grep, Write, AskUserQuestion
---

# Release Skill (typesafe-hs)

Cut a release of the single `typesafe-hs` package and publish it to
[Hackage](https://hackage.haskell.org/) following the Haskell PVP.

This repository contains **one publishable package**, `typesafe-hs`
(library + the `typesafe-hs-test` test-suite component, which ships inside the
source distribution but is **not** a separate Hackage package). There is no
inter-package dependency ordering to worry about.

## Versioning Strategy

The Haskell PVP version format is `A.B.C.D`:

- `A.B` — **major**: breaking API changes (removed/renamed exports, changed
  types, changed semantics, tightened behavior).
- `C` — **minor**: backwards-compatible API additions (new exports, new
  modules, new instances).
- `D` — **patch**: bug fixes, documentation, internal-only changes,
  performance improvements, bound relaxations that add no API.

A single annotated git tag `v<version>` marks each release.

## Arguments

`$ARGUMENTS` is optional:

- `major`, `minor`, or `patch` — forces the bump level.
- If omitted, infer the bump level from the changes (see step 2).

## Steps

### 1. Determine what changed since the last release

- Read the current version from `typesafe-hs.cabal` (the `version:` field).
- Find the latest git tag matching `v*` (`git tag --list 'v*' | sort -V | tail -1`)
  to identify the last release point. **There may be no tags yet** — if so, the
  baseline is the first commit and this is the initial public release.
- Run `git log --oneline <last-tag>..HEAD` (or the full `git log --oneline` if
  there is no tag) to list the commits in this release.
- If there are commits but a prior tag exists and `HEAD` is already at that tag,
  tell the user there is nothing to release and stop.

Present a summary:

- Current cabal version.
- Last release tag (or "none — first release").
- Number of commits since the last release.
- A short, grouped digest of those commits (features / fixes / other).

### 2. Determine the next version using PVP

Rules:

- If `$ARGUMENTS` is `major`, `minor`, or `patch`, use that bump level.
- Otherwise analyze the commit messages (Conventional Commits are used here):
  - `feat!:` / `BREAKING CHANGE` / "remove", "rename", "change type" → **major**
  - `feat:` / "add", "new", "expose", "export" → **minor**
  - `fix:` / `docs:` / `refactor:` / `test:` / `chore:` / "internal" → **patch**
  - Take the highest level implied by the set of commits.

Increment the version:

- **major**: increment `B`, reset `C` and `D` to 0 (e.g. `0.1.0.0` → `0.2.0.0`).
- **minor**: increment `C`, reset `D` to 0 (e.g. `0.1.0.0` → `0.1.1.0`).
- **patch**: increment `D` (e.g. `0.1.0.0` → `0.1.0.1`).

Present the proposed bump and the reasoning to the user and **ask for
confirmation** before proceeding.

### 3. Update the version and changelog

#### Version

- Edit `typesafe-hs.cabal` and set `version:` to the new version.
- Check whether `tested-with:` still reflects reality (currently
  `ghc ==9.12.4`); update it only if the supported compiler set changed.

#### Changelog

- Edit the root `CHANGELOG.md`. Add a new section **above** the previous
  entries, matching the existing format exactly:

  ```markdown
  ## <new-version> — <YYYY-MM-DD>

  - <bullet summarizing a change>
  ```

  Use today's date in `YYYY-MM-DD`. There is no "Unreleased" section
  convention in this repo — write the entries directly under the new version
  heading.
- Summarize the commits since the last release as bullets, grouped where it
  helps (breaking changes first for a major bump, then features, then fixes,
  then other). Keep the voice consistent with the existing `0.1.0.0` entry.

`CHANGELOG.md` and `README.md` are listed in `extra-doc-files:`, so the
updated changelog is bundled with the sdist automatically — no cabal edit is
needed for that.

Show the user the full diff (version bump + changelog) for review **before
committing**.

### 4. Verify the build and checks

Run these from the repo root and **stop on the first failure**, fixing the
issue before continuing:

- `cabal build all` — the whole project must compile.
- `cabal test` — the `typesafe-hs-test` tasty suite must pass.
- `nix flake check` — runs treefmt (fourmolu formatting) and the pre-commit
  hooks, including the commit-message literal-`\n` guard.
  - `nix flake check` evaluates the **git tree**, so `git add` any new or
    modified files first or nix will not see them.
  - If treefmt reports a formatting diff, run `nix fmt` to apply it, re-stage,
    and re-run the check.

Optional pre-release sanity check (network-dependent, not a hard gate): the
vendored OpenAPI document under `spec/openapi.json` can be compared against the
live API with `sh scripts/check-spec-drift.sh`. It needs `curl`/`jq`/`diff` and
network access and may legitimately fail offline — run it if you want to
confirm the spec has not drifted, but do not block the release on it.

### 5. Commit, tag, and push

- Stage the modified `typesafe-hs.cabal` and `CHANGELOG.md`.
- Commit with a Conventional Commits message (project convention — see the
  global CLAUDE.md): `chore(release): <new-version>`. Write a short body
  summarizing the release and why this bump level was chosen. **Do not** use
  literal `\n` escapes in the message — the `commit-msg` hook rejects them;
  use real line breaks.
- Create an annotated tag: `git tag -a v<version> -m "Release <version>"`.
- Push the commit and tag: `git push && git push --tags`.

Create the commit and tag **only after** the user has approved the version
bump and changelog.

### 6. Publish to Hackage

From the repo root:

1. `cabal check` — verify there are no packaging problems before uploading.
2. `cabal build all` and `cabal test` once more if anything changed since
   step 4.
3. `cabal sdist` to build the source tarball, then
   `cabal upload --publish <tarball-path>` to publish it.
   (Run without `--publish` first if you want a candidate-only dry run on
   Hackage; the final publish needs `--publish`.)
4. `cabal haddock --haddock-for-hackage --haddock-hyperlink-source --haddock-quickjump`
   to build the documentation tarball, then
   `cabal upload --publish --documentation <docs-tarball-path>` to publish the
   docs.
5. Report the Hackage URL:
   `https://hackage.haskell.org/package/typesafe-hs-<version>`.

Hackage publishing is **irreversible** — a version number can never be reused.
Confirm the version is correct before the `--publish` upload.

### 7. Create the GitHub release

After the Hackage upload succeeds, create a GitHub release for the tag with
`gh` (available; repo `shinzui/typesafe-hs`):

```bash
gh release create v<version> --title "v<version>" --notes "$(cat <<'EOF'
## Hackage

https://hackage.haskell.org/package/typesafe-hs-<version>

## What's Changed

<changelog entries for this version from CHANGELOG.md>
EOF
)"
```

- Use the new `CHANGELOG.md` section as the release-notes body.
- Report the GitHub release URL when done.

## Important

- Always ask the user to confirm the version bump and changelog **before**
  committing.
- Never skip the gates in step 4: `cabal build all`, `cabal test`, and
  `nix flake check` must all pass before committing.
- Create the commit and the annotated `v<version>` tag only after user
  approval of all changes.
- Hackage uploads are irreversible — double-check the version before
  `cabal upload --publish`.
- If any step fails, **stop** and report the error rather than continuing.
- `nix flake check` reads the git tree, so `git add` new files before running
  it.
