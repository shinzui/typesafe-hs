---
title: "Release candidates are proven from source distributions"
status: accepted
date: 2026-10-24
---

# Release candidates are proven from source distributions

## Context

The first consumer, `mori://shinzui/baikai/packages/baikai`, resolves release dependencies from Hackage. A successful checkout build cannot prove that a source distribution includes all fixtures, documentation and test modules or that published dependency bounds admit a consumer build.

## Decision

Before any Hackage upload, build and test the exact source-distribution tarball in a fresh project outside this checkout, with Hackage as the only package repository and the consumer's bounds as constraints. Include the specification, golden files, README, changelog and owner-approved license. Compile the README example and test its displayed code against the compiled source. Keep development-only Werror flags in cabal.project, outside the distribution.

The owner chooses the license and copyright holder. Prepare a concrete, validated tarball before requesting upload approval. Candidate upload, permanent publication, and tagging/pushing are separate owner-approved steps, as required by [the release plan](../plans/6-prepare-the-first-hackage-release-of-typesafe-hs.md).

## Consequences

A missing file, incompatible bound or unchosen license blocks release acceptance. Source and Nix builds remain useful independent checks. A preliminary build without an approved license is development evidence and cannot be promoted to a release candidate without rebuilding and checking the final tarball.
