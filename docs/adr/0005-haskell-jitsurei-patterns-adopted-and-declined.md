---
title: "Haskell-jitsurei patterns adopted and declined"
status: accepted
date: 2026-10-24
---

# Haskell-jitsurei patterns adopted and declined

## Context

The fleet patterns are `mori://shinzui/haskell-jitsurei/docs/core-standards`, `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`, `mori://shinzui/haskell-jitsurei/docs/core-multiline-strings` and `mori://shinzui/haskell-jitsurei/docs/api-servant-routes`.

## Decision

Adopt GHC2024, DeriveAnyClass, DuplicateRecordFields, OverloadedLabels, OverloadedStrings, NoFieldSelectors and OverloadedRecordDot. Use postpositive qualified imports, strict unprefixed fields and explicit deriving strategies with Generic. Enable MultilineStrings in tests only. Keep all Werror flags in cabal.project. Use NamedRoutes with auth on each route and record dot for route access; no FieldSelectors exception. Decline MultiVerb (R1 requires raw ClientError), a custom prelude (unnecessary public surface), lens dependencies (outside R1), generic aeson options (R3 needs fixed order), and server-side API patterns (the upstream document is authoritative).

## Consequences

Consumers retain generic-lens access through Generic. A later adoption of a declined pattern must supersede this decision.
