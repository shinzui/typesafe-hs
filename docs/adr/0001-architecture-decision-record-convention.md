---
title: "Architecture decision record convention"
status: accepted
date: 2026-10-24
---

# Architecture decision record convention

## Context

The repository has no profiled ADR bundle in mori.dhall.

## Decision

Keep one decision per numbered NNNN-slug.md file in docs/adr, with title, status and date frontmatter and Context, Decision and Consequences sections. Status is accepted, superseded or rejected. Never delete or renumber records; name replacements when superseding.

## Consequences

A future migration to the shared OKF profile is separate work.
