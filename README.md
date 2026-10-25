# typesafe-hs

Haskell wire types, deterministic JSON codecs and a servant client for TypeSafe's System One API. Version 0.1.0.0 targets the vendored OpenAPI 0.2.0 document fetched on 2026-10-24, including all 21 schemas, box questions, inline image assets and the model listing.

Use GHC 9.12.4. Add `typesafe-hs ^>=0.1` to your application's Cabal dependencies. `TypeSafe.Wire` exports the wire surface; `TypeSafe.V1` exports the shared servant `API`, named routes and authenticated methods. The example also imports bytestring, containers, text and vector, so list those dependencies in your application.

The example prints the exact request bytes and calls the API. Credential lookup belongs to the application. The same module is compiled by the test suite; tests exercise its pure request construction without making a live API call.

<!-- README:BEGIN -->
```haskell
{-# LANGUAGE GHC2024 #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module TypeSafe.ReadmeExample (main, request) where

import Data.ByteString.Lazy.Char8 qualified as LBS
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Data.Vector qualified as Vector
import System.Environment (lookupEnv)
import TypeSafe.V1
import TypeSafe.Wire

request :: SystemOneRequest
request =
  SystemOneRequest
    { model = jevLatest,
      state = ContentText "Checkout is unavailable.",
      questions =
        Vector.singleton
          ("urgent", QuestionNoul (NoulQuestion (Just (ContentText "Is service blocked?")) Nothing)),
      assets = Map.empty
    }

main :: IO ()
main = do
  LBS.putStrLn (encodeSystemOneRequest request)
  key <- maybe (fail "Set TYPESAFE_API_KEY") (pure . Text.pack) =<< lookupEnv "TYPESAFE_API_KEY"
  env <- getClientEnv defaultBaseUrl
  let methods = makeMethods env key
  response <- methods.createSystemOne request
  print response.answers
  print response.usage.inputTokens

```
<!-- README:END -->

The client accepts a caller-supplied servant `ClientEnv`. `getClientEnv` is a convenience using the TLS manager's defaults; construct your own environment to configure its manager. Failures throw servant-client's unchanged `ClientError`, preserving the raw status, headers and bytes in `FailureResponse`. `parseErrorBody` is a separate pure helper.

The library adds no retries, status classification, credential or base-URL environment lookup, logging, or timeout policy beyond the supplied manager. JSON bodies support inline images via `Asset.dataBase64`; multipart uploads are deferred. Enable image or long-context headers with `createSystemOneWith` and `DangerZone`.

Request questions and choice criteria encode in vector order. `encodeSystemOneRequest` returns the exact bytes servant sends. Duplicate names and labels are preserved and reported by `duplicateQuestionNames` and `duplicateChoiceLabels`; validate them before sending. Decoding JSON objects does not recover declaration order. Optional nullable content is omitted for `Nothing`; a choice-criteria value of `Nothing` encodes as JSON null.

Probabilities, confidences and scores remain `Scientific`, including extreme exponents. Required keys must be present, integral counts must fit `Int`, and unknown question or answer tags remain explicit `QuestionOther` or `AnswerOther` values. Wire decoders leave semantic validation to the caller. `ValidationError.input` is the current API's optional string preview.

Fields use plain names and the library exports no field selector functions such as `model`, `state` or `left`. Enable `OverloadedRecordDot` to read fields. Wire types derive `Generic`, so applications can also use generic-lens `#label` access and updates by importing `Data.Generics.Labels ()`; the library takes no lens dependency.

Run `nix develop -c cabal test all` for codec, golden, loopback, README and OpenAPI conformance checks. `scripts/check-spec-drift.sh` fetches and compares the published document, returning 0 for current, 1 for drift and 2 for a fetch or parse error. It writes only with `--write`. To assess another document without replacing the baseline, run the tests with `TYPESAFE_OPENAPI_SPEC=/path/to/openapi.json`.
