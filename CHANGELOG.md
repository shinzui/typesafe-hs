# Changelog

## 0.1.0.0 — 2026-10-25

- Bind all 21 schemas in the OpenAPI 0.2.0 document fetched on 2026-10-24.
- Encode ordered System One questions and choice criteria deterministically, with duplicate-reporting helpers and exact-byte goldens.
- Decode lossless Scientific answers, required fields, unknown discriminator tags, model metadata and structured error bodies, including HTTPBadRequestError.
- Expose a shared NamedRoutes servant API and client with optional danger-zone headers and unchanged ClientError failures.
- Add generated schema conformance, published examples, loopback integration, specification drift checks and a compiled README example.
- Support JSON bodies and inline image assets; defer multipart image upload.
