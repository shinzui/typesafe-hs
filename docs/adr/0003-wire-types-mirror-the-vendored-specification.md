---
title: "Wire types mirror the vendored specification"
status: accepted
date: 2026-10-24
---

# Wire types mirror the vendored specification

## Context

R2, R4, R5 and R7 in [the specification](../initial-spec.md) require a faithful, lossless wire surface.

## Decision

Bind every schema with plain strict fields, snake case converted to lower camel case and reserved type spelled type_. Use DuplicateRecordFields, NoFieldSelectors, OverloadedRecordDot and explicit stock Generic/Eq/Show deriving (name newtypes derive Eq through their representation). Every wire type has both codecs; write toEncoding explicitly. Use Scientific for probabilities and scores and bounded integral Int parsing for counts and indices. Ignore extra keys; surface unknown discriminator tags with their complete object. Do not apply semantic validation or normalize distributions in decoders. Content has string, object and array variants; optional nullable fields omit Nothing, while choice map values encode Nothing as null.

## Consequences

The approved 2026-10-24 baseline makes ValidationError.input an optional text preview, so its field is Maybe Text and rejects explicit null. HTTPBadRequestError uses a string-or-object detail union. Optional non-nullable properties reject null instead of treating it as absence.

Consumers can use generic-lens without a library lens dependency. Schema constraints are tested independently; deterministic encoders preserve question and choice vector order. Decoded object order is unspecified.
