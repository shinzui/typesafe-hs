# typesafe-hs initial specification

This document specifies the first release of `typesafe-hs`, a Haskell client for TypeSafe's System One API (`POST /v1/systemone`, `GET /v1/models` at `https://api.typesafe.ai`). Its first consumer is the `baikai-typesafe` provider planned in `mori://shinzui/baikai/plans/84-deliver-the-typesafe-system-one-provider-and-judgment-catalog`, so the requirements below are written so that a client meeting them can be dropped into that plan without an adapter-side workaround. Requirements are numbered R1 to R12 so the baikai plan can cite them; everything else is guidance.

The surface Baikai depends on is deliberately small: the wire types, JSON codecs and pure helpers that mirror the official OpenAPI document. The library also ships a servant `API` type over those wire types and a servant-client `makeMethods`, in the shape of the `openai` and `claude` packages Baikai already consumes, for consumers other than Baikai's provider. Anything that retries, reads the environment or classifies failures is absent.


## Why an in-house client

Baikai first evaluated the community SDK at `mori://byteally/typesafe-sdk` (packages `typesafe-ai` and `typesafe-ai-core`, 0.1.0.0 on Hackage, inspected 2026-10-21). Its `TypeSafe.Wire` module is a sound mirror of the specification and its conformance-test approach is worth copying, but it is a release-blocking dependency maintained outside this project, its record fields carry type-name prefixes that this project's conventions forbid, and its client layer bundles retries, timeouts, credential lookup and status classification that Baikai's architecture assigns elsewhere. Owning the client keeps the specification mirror, its drift handling and its release cadence under this project's control.


## Protocol baseline

The protocol baseline is TypeSafe's OpenAPI document, version 0.2.0, published at https://api.typesafe.ai/openapi.json. Vendor a copy at `spec/openapi.json` and expose its `info.version` as a constant (`apiSpecVersion`). Until this repository vendors it, a reference copy is readable in the registered community SDK at `mori://byteally/typesafe-sdk/packages/typesafe-ai-core`, project-relative path `typesafe-sdk/typesafe-ai-core/spec/openapi.json` (artifact-level URI pending).

The schemas that matter are `SystemOneRequest`, `Question` with `NoulQuestion`, `NoulCriteria`, `ChoiceQuestion` and `ScoreQuestion`, `SystemOneResponse`, `Answer` with `NoulAnswer`, `ChoiceAnswer` and `ScoreAnswer`, `Usage`, `ModelMetadataList`, `ModelMetadata`, `HTTPValidationError` and `ValidationError`. The facts that earlier descriptions of this API (DSPy 3.4.0's vendored client) got wrong, and that this client must get right, are: a choice answer carries a required `confidence`; a score answer carries required `score`, `confidence`, `legend` and `probabilities`; a noul question accepts an optional `criteria` object with `true` and `false` descriptions; a success response requires `model`, `answers` and `usage`; `state` is a string, object or array, never a number, boolean or null; `instructions` and criteria descriptions are string, object, array or null; and validation failures are HTTP 422 with a `detail` array of `{loc, msg, type}` entries.


## Requirements from Baikai

**R1. The library carries no policy: no retries, no classification, no environment lookups.** The library is a servant-style SDK in the shape of the Mercury `openai` and `claude` packages: wire types and codecs that are usable on their own, a servant `API` type over them, and a `makeMethods` that runs that type with servant-client against a caller-supplied `ClientEnv`. What it must not contain is policy that Baikai's architecture assigns elsewhere: no retry loop (`mori://shinzui/baikai`, `docs/adr/0005-what-baikai-deliberately-does-not-do.md`, artifact-level URI pending), no mapping of statuses or exceptions to categories or retryability (`docs/adr/0011-core-owns-transport-failure-classification.md`), no timeout policy beyond what the caller's `Manager` carries, no credential or base-URL lookup from the environment, and no logging hook. A `getClientEnv :: Text -> IO ClientEnv` convenience like Mercury's is fine; reading `TYPESAFE_API_KEY` belongs in examples and applications. Failures from `makeMethods` surface as servant-client's `ClientError`, with the raw response kept inside `FailureResponse`, and nothing is layered on top of it. Dependencies are `base`, `aeson`, `bytestring`, `containers`, `scientific`, `text`, `vector`, `http-types`, `servant` and `servant-client`, plus whatever servant-client itself brings. Baikai's provider uses only the types and codecs and makes its own http-client call on its cached `ClientEnv`, exactly as it does with the Mercury packages; the servant client is for other consumers and for the models listing.

**R2. Every schema in the specification has a Haskell type, and every property a field with its plain name.** `SystemOneRequest` has fields `model`, `state` and `questions`; `ChoiceAnswer` has `choice`, `confidence` and `probabilities`; and so on, with no type-name prefix on any field. Baikai uses `OverloadedRecordDot` and forbids Hungarian-style prefixes, so this library enables `DuplicateRecordFields` and `OverloadedRecordDot` rather than renaming fields. Schemas that use `oneOf` with a `type` discriminator (`Question`, `Answer`) become sum types whose constructors imply the tag. Field order and names must be checkable against the vendored document by a test (see R10), not by reading.

**R3. Request encoding is deterministic and yields the exact bytes.** Provide `encodeSystemOneRequest :: SystemOneRequest -> Data.ByteString.Lazy.ByteString` built on `toEncoding`, with a fixed top-level key order and no intermediate `Value`. Baikai commits to the bytes it sends as call evidence and asserts the fixture body on a loopback server, so the same value must always encode to the same bytes. Choice criteria are an ordered sequence of `(label, Maybe description)` pairs, encoded in declared order; a `Map` is not acceptable because Baikai preserves the caller's enum order. Score criteria are an ordered non-empty sequence. The `questions` field is an ordered sequence of `(name, Question)` pairs encoded in that order; uniqueness of names is checked by a smart constructor or reported by a pure validation function, not silently collapsed. Absent optional fields (`instructions`, noul `criteria`, a choice description that is `Nothing`) are omitted, and a `null` description is written as JSON `null`, because the API distinguishes "no description" from "null description" only at the wire. The servant `JSON` content type renders a request body with aeson's `encode`, which uses the same `toEncoding`, so a body sent through `makeMethods` must be byte-equal to `encodeSystemOneRequest` of the same value; a test asserts this.

**R4. Numbers are lossless on the wire.** Every probability, confidence and score field holds a `Scientific`, not a `Double`. Baikai validates that each probability and confidence is within [0, 1] and that each score is finite *before* converting to `Double`, so a reply such as `1e400` must reach it intact rather than as `Infinity`. Token counts are decoded as integers and rejected when the JSON number is not integral. The library may offer helpers such as `unitInterval :: Scientific -> Either Text Double`, but its `FromJSON` instances must not apply them: the wire layer accepts exactly what the schema accepts and leaves semantic validation to the consumer. The library never normalizes, clamps or re-sums a distribution.

**R5. Required means required; unknown means surfaced, never dropped.** Decoding a success body fails when `model`, `answers` or `usage` is missing, when a choice answer lacks `confidence`, when a score answer lacks `score`, `confidence`, `legend` or `probabilities`, or when `usage` lacks either token count. Unknown additional properties on known objects are ignored, for forward compatibility. A `Question` or `Answer` whose `type` is not `noul`, `choice` or `score` decodes to an explicit constructor (`QuestionOther tag object`, `AnswerOther tag object`) that carries the tag and the complete object, so Baikai can refuse it by name; it is never dropped and never coerced to a known constructor. `legend` is exposed verbatim as a map from the level key text to its description, because Baikai checks it against the declared levels.

**R6. Error bodies have codecs; statuses have no classification here.** Provide types for the HTTP 422 body (`HTTPValidationError` with its `ValidationError` entries and `loc` segments that are either field names or array indices) and for the structured error forms the service uses elsewhere, which have been observed as `{"detail": {"error_type": …, "message": …}}` and `{"detail": "message"}`, plus a pure `parseErrorBody :: Data.ByteString.Lazy.ByteString -> ErrorBody` that falls back to raw JSON, raw text or empty. Do not map status codes to categories, retryability or exceptions in this library; Baikai's `httpError` does that. Pure constants are welcome: the request-id header name `x-typesafe-request-id`, the path segments for `/v1/systemone` and `/v1/models`, and the default base URL `https://api.typesafe.ai`.

**R7. Content is the specification's union, not a string.** `state`, `instructions` and criteria descriptions are represented by a `Content` type with text, object and array constructors (plus null where the schema allows it), with `contentFromValue :: Value -> Maybe Content` and `contentToValue`. Baikai embeds a caller's JSON `Value` unchanged as the state and must be able to tell, by path, when a caller supplied a scalar or null that the API would reject. The library must not stringify a non-string value to make it fit.

**R8. Names are open.** `ModelName` and `QuestionName` are newtypes over `Text` with `IsString`; any alias or versioned id the API accepts is representable. Constants for `jev-latest` and `jev-preview` are fine, but nothing in the library infers behaviour from a name.

**R9. The models endpoint is bound.** `ModelMetadataList` and `ModelMetadata` (`name`, `description`, `release_date` as text, with a helper to parse the day) decode the `GET /v1/models` body. Baikai does not need this for its first release, but a complete mirror is what makes the conformance test meaningful.

**R10. Conformance is tested against the vendored document.** A test suite loads `spec/openapi.json` and checks that every operation and schema is bound, that every property is encoded, that required properties are required and optional ones optional in the Haskell codecs, that the discriminator mappings match the constructors, that the document's own examples decode, and that `apiSpecVersion` equals the document's `info.version`. A failure must be a test failure, not a silent pass, when the document uses a JSON Schema keyword the test does not understand. A script fetches the published document and reports whether the vendored copy is current.

**R11. Baikai's fixture is a golden test here.** The request below must encode to a document structurally equal to the JSON shown (compare structure and scalar types; key order inside objects is the library's fixed order), and the response below must decode to the expected values with `confidence`, `score` and `legend` present. The same response with `confidence` or `score` removed must fail to decode. Keep these as checked-in golden files.

```json
{
  "model": "jev-latest",
  "state": {"ticket": "Checkout is unavailable."},
  "questions": {
    "urgent": {"type": "noul", "instructions": "Is service blocked?"},
    "category": {"type": "choice", "instructions": "Classify the issue.", "criteria": {"billing": "Payment issue", "technical": "Product malfunction"}},
    "severity": {"type": "score", "instructions": "Rate impact.", "criteria": ["Minor", "Disruptive", "Blocking"]}
  }
}
```

```json
{
  "answers": {
    "urgent": {"type": "noul", "noul": 0.83},
    "category": {"type": "choice", "probabilities": {"billing": 0.2, "technical": 0.7}, "choice": "technical", "confidence": 0.65},
    "severity": {"type": "score", "probabilities": {"0": 0.1, "1": 0.3, "2": 0.6}, "score": 1.5, "confidence": 0.55, "legend": {"0": "Minor", "1": "Disruptive", "2": "Blocking"}}
  },
  "usage": {"input_tokens": 120, "output_tokens": 3},
  "model": "jev-fixture-version"
}
```

**R12. Packaging fits Baikai's workspace and release process.** The package follows the PVP. It builds on GHC 9.12.4, which is Baikai's `tested-with` compiler and the compiler this repository's Nix shell provides; supporting 9.6 through 9.14 is desirable but not required for the first release. Its dependency bounds must intersect Baikai's: `aeson ^>=2.2`, `base >=4.20 && <5`, `bytestring ^>=0.12`, `containers ^>=0.7`, `scientific ^>=0.3`, `text ^>=2.1`, `vector ^>=0.13`, `http-types ^>=0.12`, `servant-client ^>=0.20`, and a `servant` bound compatible with that servant-client. Before `baikai-typesafe` can be released, this library must be on Hackage under its declared package name, because Baikai's release gate builds each source distribution in an isolated project that resolves from Hackage only; during development Baikai may reference this repository with a `source-repository-package` stanza. The repository is registered in Mori as `mori://shinzui/typesafe-hs` (registration pending at the time of writing) so that Baikai's documents can cite its packages and this specification by canonical URI. The published package name is this project's decision; the Nix wiring currently calls the root package `typesafe-hs`.


## Suggested library surface

The module names are this project's choice; Baikai only needs the surface. A sketch that satisfies R1 to R9:

```haskell
module TypeSafe.Wire
  ( apiSpecVersion,
    ModelName (..),
    QuestionName (..),
    Content (..),
    contentFromValue,
    contentToValue,

    -- POST /v1/systemone
    SystemOneRequest (..),
    Question (..),
    NoulQuestion (..),
    NoulCriteria (..),
    ChoiceQuestion (..),
    ScoreQuestion (..),
    encodeSystemOneRequest,
    SystemOneResponse (..),
    Answer (..),
    NoulAnswer (..),
    ChoiceAnswer (..),
    ScoreAnswer (..),
    Usage (..),
    decodeSystemOneResponse,

    -- GET /v1/models
    ModelMetadataList (..),
    ModelMetadata (..),

    -- Error bodies
    ErrorBody (..),
    HTTPValidationError (..),
    ValidationError (..),
    LocationSegment (..),
    parseErrorBody,

    -- Pure constants
    requestIdHeader,
    systemOnePath,
    modelsPath,
    defaultBaseUrl,
  )
where
```

```haskell
data SystemOneRequest = SystemOneRequest
  { model :: !ModelName,
    state :: !Content,
    questions :: !(Vector (QuestionName, Question))
  }

data ChoiceQuestion = ChoiceQuestion
  { instructions :: !(Maybe Content),
    criteria :: !(Vector (Text, Maybe Content))
  }

data ChoiceAnswer = ChoiceAnswer
  { choice :: !Text,
    confidence :: !Scientific,
    probabilities :: !(Map Text Scientific)
  }

data ScoreAnswer = ScoreAnswer
  { score :: !Scientific,
    confidence :: !Scientific,
    legend :: !(Map Text Content),
    probabilities :: !(Map Text Scientific)
  }
```

Decoding a request body is not required by Baikai; if it is implemented, document that `questions` order after decoding is unspecified, because aeson objects do not preserve key order.

The servant layer, in the Mercury shape:

```haskell
module TypeSafe.V1
  ( API,
    getClientEnv,
    makeMethods,
    Methods (..),
  )
where

type API =
  Header' '[Required, Strict] "Authorization" Text
    :> "v1"
    :> ( "systemone" :> ReqBody '[JSON] SystemOneRequest :> Post '[JSON] SystemOneResponse
           :<|> "models" :> Get '[JSON] ModelMetadataList
       )

data Methods = Methods
  { createSystemOne :: SystemOneRequest -> IO SystemOneResponse,
    listModels :: IO ModelMetadataList
  }

-- Parses the base URL and builds a TLS 'ClientEnv'; no environment lookup.
getClientEnv :: Text -> IO ClientEnv

-- Runs the API against the given environment with a bearer token. Each
-- method throws servant-client's 'ClientError' on failure and adds nothing
-- to it.
makeMethods :: ClientEnv -> Text -> Methods
```

The same `API` type serves the mock server in this project's tests and may serve Baikai's loopback fixture, so one definition describes the wire for both sides.


## Outside Baikai's requirements

A typed question layer (choice options and score levels as Haskell enumerations, applicative composition of questions), retries honouring `Retry-After`, configuration from `TYPESAFE_API_KEY` and `TYPESAFE_BASE_URL`, and logging hooks are all useful and belong in a separate package or in applications. None of them may leak into the library described by R1. Baikai will keep its own strict validator (names, kinds, declared keys, bounds, refusal of unknown constructors) on top of this library regardless of what the typed layer validates, so the wire layer should not try to be strict on Baikai's behalf.


## Open decisions

The published package and module names (R12, surface sketch). Whether to vendor `spec/openapi.json` before or after the first Cabal package exists; R10 needs it either way. Whether `questions` should be a `Vector` of pairs or a dedicated ordered type with a uniqueness-checking smart constructor; both satisfy R3.


## References

- Baikai project: `mori://shinzui/baikai`
- Provider plan: `mori://shinzui/baikai/plans/84-deliver-the-typesafe-system-one-provider-and-judgment-catalog`
- Content plan: `mori://shinzui/baikai/plans/83-preserve-structured-data-and-probability-evidence-across-baikai`
- Improvement request: `mori://shinzui/baikai/okf/improvement-requests/concepts/IR-10`
- Baikai ADRs cited above: `mori://shinzui/baikai`, project-relative paths `docs/adr/0005-what-baikai-deliberately-does-not-do.md` and `docs/adr/0011-core-owns-transport-failure-classification.md` (artifact-level URIs pending)
- Community SDK used as a reference: `mori://byteally/typesafe-sdk/packages/typesafe-ai-core`
- Official specification: https://api.typesafe.ai/openapi.json (version 0.2.0 as of 2026-10-21)
