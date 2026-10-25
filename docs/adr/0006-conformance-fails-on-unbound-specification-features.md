---
title: "Conformance fails on unbound specification features"
status: accepted
date: 2026-10-24
---

# Conformance fails on unbound specification features

## Context

R10 in [the specification](../initial-spec.md) requires mechanical proof that the public wire surface matches the vendored OpenAPI document. The version label has remained unchanged across upstream schema changes, so matching the version alone cannot establish compatibility.

## Decision

Keep the JSON Schema validator and OpenAPI audits in the test suite. Unknown schema keywords, OpenAPI fields, parameter locations, content types, schemas and operations fail conformance. A binding table connects every object property to a getter using the public Haskell field name. Generated values validate against the document, encode consistently and require exactly the declared required keys.

Compare JSON values for round trips involving ordered question or choice vectors, because decoding JSON objects cannot recover declaration order. Byte order is separately proven by fixed goldens and the loopback servant test. Compare the known union constructors with both discriminator mappings and test unknown-tag pass-through separately from schema-valid generators.

The only excluded content type is multipart/form-data for POST /v1/systemone, tracked in [the multipart follow-up](../plans/7-send-images-with-multipart-system-one-requests.md). The TYPESAFE_OPENAPI_SPEC override belongs only to tests and supplies the same document to version and conformance checks.

## Consequences

A changed document can be assessed without overwriting the baseline. Mutation checks prove that new keywords, schemas, content types and operations cause failures. Consumer applications still own semantic validation; this test-only validator adds no library dependency or runtime policy.
