module TypeSafe.Wire.ResponseTest (tests, fixture) where

import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseEither)
import Data.ByteString.Lazy qualified as LBS
import Data.Either (isLeft)
import Data.Map.Strict qualified as Map
import Data.Scientific (scientific)
import Data.Time.Calendar (fromGregorian)
import Data.Vector qualified as Vector
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Wire

fixture :: SystemOneResponse
fixture =
  SystemOneResponse
    "jev-fixture-version"
    ( Map.fromList
        [ ("urgent", AnswerNoul (NoulAnswer 0.83)),
          ("category", AnswerChoice (ChoiceAnswer "technical" 0.65 (Map.fromList [("billing", 0.2), ("technical", 0.7)]))),
          ( "severity",
            AnswerScore
              ( ScoreAnswer
                  1.5
                  0.55
                  (Map.fromList [("0", ContentText "Minor"), ("1", ContentText "Disruptive"), ("2", ContentText "Blocking")])
                  (Map.fromList [("0", 0.1), ("1", 0.3), ("2", 0.6)])
              )
          )
        ]
    )
    (Usage 120 3)

tests :: TestTree
tests =
  testGroup
    "Wire.Response"
    [ testGroup
        "success bodies"
        [ testCase "baikai golden decodes to all expected values" $ do
            bytes <- LBS.readFile "test/golden/baikai-response.json"
            decodeSystemOneResponse bytes @?= Right fixture
            fixture.usage.inputTokens @?= 120,
          testCase "negative goldens fail" $
            mapM_
              ( \name -> do
                  bytes <- LBS.readFile ("test/golden/baikai-response-missing-" <> name <> ".json")
                  assertBool name (isLeft (decodeSystemOneResponse bytes))
              )
              ["confidence", "score"],
          testCase "huge numbers survive without semantic validation" $ do
            eitherDecode @NoulAnswer "{\"type\":\"noul\",\"noul\":1e400}" @?= Right (NoulAnswer (scientific 1 400))
            assertBool "overflow" (isLeft (finiteDouble (scientific 1 400)))
            assertBool "unit interval" (isLeft (unitInterval 1.5))
            unitInterval 0.5 @?= Right 0.5
            eitherDecode @ChoiceAnswer "{\"type\":\"choice\",\"choice\":\"x\",\"confidence\":1.5,\"probabilities\":{}}" @?= Right (ChoiceAnswer "x" 1.5 Map.empty),
          testCase "token counts are bounded integral Ints" $ do
            assertBool "fraction" (isLeft (eitherDecode @Usage "{\"input_tokens\":3.5,\"output_tokens\":1}"))
            assertBool "range" (isLeft (eitherDecode @Usage "{\"input_tokens\":1e30,\"output_tokens\":1}"))
            eitherDecode @Usage "{\"input_tokens\":1.2e3,\"output_tokens\":0}" @?= Right (Usage 1200 0),
          testCase "unknown answers retain their complete object" $ do
            let v = object ["type" .= String "polygon", "points" .= ([1, 2] :: [Int])]
            a <- either fail pure (parseEither parseJSON v :: Either String Answer)
            case a of
              AnswerOther tag o -> do
                tag @?= "polygon"
                Object o @?= v
              _ -> assertFailure "unknown answer coerced"
            toJSON a @?= v
            eitherDecode @Value (encode a) @?= Right v,
          testCase "required fields of each success object" $ do
            missing fixture ["model", "answers", "usage"]
            missing (ChoiceAnswer "x" 0.2 Map.empty) ["type", "choice", "confidence", "probabilities"]
            missing (ScoreAnswer 1 0.2 Map.empty Map.empty) ["type", "score", "confidence", "legend", "probabilities"]
            missing (Usage 1 2) ["input_tokens", "output_tokens"]
            missing (BoxAnswer (BoxCoordinates 0 1 0 1) Nothing) ["type", "box", "confidence"]
            assertBool "bad tag" (isLeft (eitherDecode @Answer "{\"type\":7}")),
          testCase "extra fields ignored and nullable confidence retained" $ do
            eitherDecode @NoulAnswer "{\"type\":\"noul\",\"noul\":2,\"rationale\":\"x\"}" @?= Right (NoulAnswer 2)
            let box = BoxAnswer (BoxCoordinates 0 1 0 1) Nothing
            eitherDecode @BoxAnswer (encode box) @?= Right box
            eitherDecode @SystemOneResponse (encode fixture) @?= Right fixture
            eitherDecode @Value (encode fixture) @?= Right (toJSON fixture)
        ],
      testGroup
        "model listing"
        [ testCase "listing decodes, ignores tags and parses day" $ do
            m <- either fail pure (eitherDecode @ModelMetadataList "{\"models\":[{\"name\":\"jev-latest\",\"description\":\"General\",\"release_date\":\"2026-09-15\",\"tags\":[\"default\"]}]}")
            releaseDay (Vector.head m.models) @?= Just (fromGregorian 2026 9 15)
            eitherDecode @ModelMetadataList (encode m) @?= Right m,
          testCase "required metadata fields and verbatim unusual date" $ do
            missing (ModelMetadata "m" "d" "soon") ["name", "description", "release_date"]
            missing (ModelMetadataList Vector.empty) ["models"]
            releaseDay (ModelMetadata "m" "d" "soon") @?= Nothing
            releaseDay (ModelMetadata "m" "d" "2026-13-01") @?= Nothing
        ],
      testGroup
        "error bodies"
        [ testCase "validation detail with bounded location index and string preview" $ do
            let v = ValidationError (Vector.fromList [LocationField "body", LocationIndex 0]) "required" "missing" (Just "null") (Just (KeyMap.singleton "min_length" (Number 1)))
                body = HTTPValidationError (Just (Vector.singleton v))
            parseErrorBody (encode body) @?= ErrorBodyValidation body
            eitherDecode @ValidationError (encode v) @?= Right v
            eitherDecode @HTTPValidationError "{}" @?= Right (HTTPValidationError Nothing),
          testCase "current HTTPBadRequestError union" $ do
            eitherDecode @HTTPBadRequestError "{\"detail\":\"bad request\"}" @?= Right (HTTPBadRequestError (BadRequestDetailText "bad request"))
            let b = HTTPBadRequestError (BadRequestDetailObject (KeyMap.singleton "message" (String "x")))
            eitherDecode @HTTPBadRequestError (encode b) @?= Right b
            missing b ["detail"]
            assertBool "null rejected" (isLeft (eitherDecode @HTTPBadRequestError "{\"detail\":null}")),
          testCase "structured and text detail" $ do
            parseErrorBody "{\"detail\":{\"error_type\":\"api_usage_error\",\"message\":\"Unknown model: x\"}}" @?= ErrorBodyDetail (ErrorDetail (Just "api_usage_error") "Unknown model: x")
            parseErrorBody "{\"detail\":\"fastapi style\"}" @?= ErrorBodyDetailText "fastapi style",
          testCase "unrecognized or malformed JSON stays raw" $
            mapM_
              ( \bytes -> do
                  v <- either fail pure (eitherDecode @Value bytes)
                  parseErrorBody bytes @?= ErrorBodyJson v
              )
              [ "{}",
                "{\"error\":{\"message\":\"invalid api key\"}}",
                "{\"error\":\"plain string\"}",
                "{\"message\":\"top-level message\"}",
                "{\"code\":7}",
                "{\"detail\":[{\"msg\":\"no loc\"}]}",
                "{\"detail\":[{\"loc\":[1.5],\"msg\":\"m\",\"type\":\"t\"}]}",
                "{\"detail\":[{\"loc\":[1e30],\"msg\":\"m\",\"type\":\"t\"}]}",
                "{\"detail\":[{\"loc\":[],\"msg\":\"m\",\"type\":\"t\",\"input\":null}]}"
              ],
          testCase "text, invalid UTF8 and empty" $ do
            parseErrorBody "<h1>bad gateway</h1>" @?= ErrorBodyText "<h1>bad gateway</h1>"
            parseErrorBody (LBS.pack [255, 254]) @?= ErrorBodyText "\xfffd\xfffd"
            parseErrorBody "" @?= ErrorBodyEmpty
        ]
    ]

missing :: forall a. (ToJSON a, FromJSON a) => a -> [Key] -> Assertion
missing value keys = case toJSON value of
  Object o ->
    mapM_
      ( \key ->
          assertBool
            ("required " <> show key)
            (isLeft (parseEither (parseJSON @a) (Object (KeyMap.delete key o))))
      )
      keys
  _ -> assertFailure "expected object fixture"
