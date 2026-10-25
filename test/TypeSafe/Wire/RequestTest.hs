module TypeSafe.Wire.RequestTest (tests, fixture) where

import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseEither)
import Data.ByteString.Char8 qualified as Strict
import Data.ByteString.Lazy qualified as LBS
import Data.ByteString.Lazy.Char8 qualified as B
import Data.Either (isLeft)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Data.Vector qualified as Vector
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Wire

fixture :: SystemOneRequest
fixture =
  SystemOneRequest
    jevLatest
    (ContentObject (KeyMap.singleton "ticket" (String "Checkout is unavailable.")))
    ( Vector.fromList
        [ ("urgent", QuestionNoul (NoulQuestion (Just (ContentText "Is service blocked?")) Nothing)),
          ( "category",
            QuestionChoice
              ( ChoiceQuestion
                  (Just (ContentText "Classify the issue."))
                  (Vector.fromList [("billing", Just (ContentText "Payment issue")), ("technical", Just (ContentText "Product malfunction"))])
              )
          ),
          ( "severity",
            QuestionScore
              ( ScoreQuestion
                  (Just (ContentText "Rate impact."))
                  (ContentText "Minor" :| [ContentText "Disruptive", ContentText "Blocking"])
              )
          )
        ]
    )
    Map.empty

tests :: TestTree
tests =
  testGroup
    "TypeSafe.Wire.Request"
    [ testCase "structural golden R11" $ do
        expected <- either fail pure =<< eitherDecodeFileStrict @Value "test/golden/baikai-request.json"
        eitherDecode @Value (encodeSystemOneRequest fixture) @?= Right expected,
      testCase "exact bytes golden R3" $ do
        expected <- LBS.readFile "test/golden/baikai-request.bytes"
        encodeSystemOneRequest fixture @?= expected,
      testCase "encode and deterministic helper agree" $ do
        encode fixture @?= encodeSystemOneRequest fixture
        encodeSystemOneRequest fixture @?= encodeSystemOneRequest fixture,
      testCase "declared question and choice order" $ do
        let q = QuestionChoice (ChoiceQuestion Nothing (Vector.fromList [("technical", Nothing), ("billing", Nothing)]))
            r = SystemOneRequest "m" (ContentText "s") (Vector.fromList [("z", q), ("a", q), ("m", q)]) Map.empty
        encode r @?= "{\"model\":\"m\",\"state\":\"s\",\"questions\":{\"z\":{\"type\":\"choice\",\"criteria\":{\"technical\":null,\"billing\":null}},\"a\":{\"type\":\"choice\",\"criteria\":{\"technical\":null,\"billing\":null}},\"m\":{\"type\":\"choice\",\"criteria\":{\"technical\":null,\"billing\":null}}}}",
      testCase "optional fields and nullable values" $ do
        encode (NoulQuestion Nothing Nothing) @?= "{\"type\":\"noul\"}"
        encode (NoulCriteria (Just (ContentText "y")) Nothing) @?= "{\"true\":\"y\"}"
        eitherDecode @NoulQuestion "{\"type\":\"noul\",\"instructions\":null}" @?= Right (NoulQuestion Nothing Nothing),
      testCase "unknown tag preserves complete object" $ do
        let v = object ["type" .= ("future" :: Text.Text), "x" .= ([1, 2] :: [Int])]
        q <- either fail pure (parseEither parseJSON v :: Either String Question)
        case q of
          QuestionOther tag obj -> do
            tag @?= "future"
            Object obj @?= v
            toJSON q @?= v
            eitherDecode @Value (encode q) @?= Right v
          _ -> assertFailure "unknown question was coerced",
      testCase "content remains structured and scalar state fails" $ do
        let r = SystemOneRequest "m" (ContentArray Vector.empty) Vector.empty Map.empty
        eitherDecode @Value (encode r) @?= Right (toJSON r)
        assertBool "array, not string" (Strict.isInfixOf "\"state\":[]" (LBS.toStrict (encode r)))
        mapM_
          (\v -> assertBool "scalar rejected" (isLeft (eitherDecode @SystemOneRequest v)))
          ["{\"model\":\"m\",\"state\":42,\"questions\":{}}", "{\"model\":\"m\",\"state\":null,\"questions\":{}}"],
      testCase "assets absent or nonempty" $ do
        assertBool "empty omitted" (not (Strict.isInfixOf "\"assets\"" (LBS.toStrict (encode fixture))))
        r <- either fail pure (eitherDecode @SystemOneRequest (encode fixture))
        r.assets @?= Map.empty
        let a = Asset (Just ImageFormatPng) (Just "AA==") Nothing
            withAsset = SystemOneRequest fixture.model fixture.state fixture.questions (Map.singleton "photo" a)
        assertBool "inline asset" (Strict.isInfixOf "\"assets\":{\"photo\":{\"type\":\"image\",\"format\":\"png\",\"data_base64\":\"AA==\"}}" (LBS.toStrict (encode withAsset)))
        eitherDecode @Asset (encode a) @?= Right a,
      testCase "published request examples decode" $ do
        spec <- either fail pure =<< eitherDecodeFileStrict @Value "spec/openapi.json"
        examples <-
          either fail pure $
            parseEither
              ( withObject "spec" $ \o -> do
                  paths <- o .: "paths"
                  post <- (paths .: "/v1/systemone") >>= (.: "post")
                  body <- post .: "requestBody"
                  content <- body .: "content"
                  json <- content .: "application/json"
                  json .: "examples"
              )
              spec
        mapM_
          ( \(name, example) -> do
              value <- either fail pure $ parseEither (withObject "example" (.: "value")) example
              q <- either fail pure (parseEither parseJSON value :: Either String SystemOneRequest)
              assertBool (show name) (not (Vector.null q.questions))
          )
          (KeyMap.toList examples),
      testCase "duplicates are reported without collapsing bytes" $ do
        let q = QuestionBox (BoxQuestion Nothing)
            r = SystemOneRequest "m" (ContentText "s") (Vector.fromList [("a", q), ("b", q), ("a", q), ("a", q), ("b", q)]) Map.empty
        duplicateQuestionNames r @?= ["a", "b"]
        length (Text.breakOnAll "\"a\":" (Text.pack (B.unpack (encode r)))) @?= 3
        duplicateChoiceLabels (ChoiceQuestion Nothing (Vector.fromList [("billing", Nothing), ("billing", Nothing)])) @?= ["billing"],
      testCase "required fields and malformed known tags fail" $ do
        assertBool "choice criteria required" (isLeft (eitherDecode @ChoiceQuestion "{\"type\":\"choice\"}"))
        assertBool "nonempty score" (isLeft (eitherDecode @ScoreQuestion "{\"type\":\"score\",\"criteria\":[]}"))
        assertBool "state required" (isLeft (eitherDecode @SystemOneRequest "{\"model\":\"m\",\"questions\":{}}"))
        assertBool "known malformed is not Other" (isLeft (eitherDecode @Question "{\"type\":\"choice\"}"))
    ]
