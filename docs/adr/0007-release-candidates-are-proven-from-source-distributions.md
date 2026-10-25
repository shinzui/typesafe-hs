---
title: "Release candidates are proven from source distributions"
status: accepted
date: 2026-10-25
---

# Release candidates are proven from source distributions

## Context

The first consumer, `mori://shinzui/baikai/packages/baikai`, resolves release dependencies from Hackage. A successful checkout build cannot prove that a source distribution includes all fixtures, documentation and test modules or that published dependency bounds admit a consumer build.

## Decision

Before any Hackage upload, build and test the exact source-distribution tarball in a fresh project outside this checkout, with Hackage as the only package repository and the consumer's bounds as constraints. Include the specification, golden files, README, changelog and owner-approved license. Compile the README example and test its displayed code against the compiled source. Keep development-only Werror flags in cabal.project, outside the distribution.

Extract the exact tarball and name its directory as the scratch project package: Cabal 3.16 treats a tarball target as global-style and does not select its test suite through `cabal test all`. Verify dependency API minimums against released source and current bounds against Hackage and upstream release tags; the Mori corpus can contain unreleased versions.

The owner chose BSD-3-Clause with Copyright (c) 2026 Nadeem Bitar for the initial release on 2026-10-25. Future changes to the license or copyright holder require an owner decision. Prepare a concrete, validated tarball before requesting upload approval. Candidate upload, permanent publication, and tagging/pushing require owner authorization. An explicit instruction to proceed with the complete validated release authorizes the full sequence; do not request the same permission again. The execution evidence belongs in [the release plan](../plans/6-prepare-the-first-hackage-release-of-typesafe-hs.md).

## Consequences

A missing file, incompatible bound or unchosen license blocks release acceptance. Source and Nix builds remain useful independent checks. A preliminary build without an approved license is development evidence and cannot be promoted to a release candidate without rebuilding and checking the final tarball. Hackage publication can precede signed-index propagation: verify both direct package/documentation downloads and discovery through a fresh `cabal update` and `cabal info` before closing the release plan. If the configured HTTP endpoint retains older metadata after HTTPS has refreshed, verify with a temporary HTTPS configuration while preserving user settings. A stale index does not justify re-uploading an already published version.
