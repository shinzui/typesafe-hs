---
title: "The library carries no transport policy"
status: accepted
date: 2026-10-24
---

# The library carries no transport policy

## Context

R1 in [the specification](../initial-spec.md) assigns policy to consumers. The boundary follows `mori://shinzui/baikai`, project-relative paths `docs/adr/0005-what-baikai-deliberately-does-not-do.md` and `docs/adr/0011-core-owns-transport-failure-classification.md` (artifact-level URIs pending).

## Decision

Expose wire codecs and a servant client. Preserve servant-client ClientError unchanged, including FailureResponse bodies. Add no retries, failure classification, timeout overrides, environment lookup or logging hooks. A TLS getClientEnv convenience is allowed.

## Consequences

Applications own policy and credentials. The policy-bearing client from `mori://byteally/typesafe-sdk` is a reference, not a dependency.
