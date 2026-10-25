---
title: "The first release targets the published document with JSON bodies only"
status: accepted
date: 2026-10-24
---

# The first release targets the published document with JSON bodies only

## Context

The published 0.2.0 document drifted without a version bump on both 2026-10-21 and 2026-10-24. On 2026-10-24 the user approved the 21-schema baseline, including HTTPBadRequestError.

## Decision

Vendor the current document and compare content to detect future drift. Bind all schemas and both danger-zone headers. Send application/json only; inline images use Asset.data_base64. Defer multipart uploads to [the follow-up plan](../plans/7-send-images-with-multipart-system-one-requests.md).

## Consequences

Conformance explicitly tests multipart as an exclusion. Adding servant-multipart dependencies requires the follow-up scope decision; no request classification follows from documenting HTTP 400.
