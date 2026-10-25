module TypeSafe.Wire.CommonTest (tests) where

import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Vector qualified as Vector
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Wire

tests :: TestTree
tests =
  testGroup "TypeSafe.Wire.Common" $
    [ testCase "string" $ decode @Content "\"hi\"" @?= Just (ContentText "hi"),
      testCase "object" $ decode @Content "{}" @?= Just (ContentObject KeyMap.empty),
      testCase "array" $ decode @Content "[]" @?= Just (ContentArray Vector.empty),
      testCase "name newtypes" $ do
        encode (ModelName "jev-latest") @?= "\"jev-latest\""
        encode ("x" :: QuestionName) @?= "\"x\"",
      testCase "constants" $ do
        jevLatest @?= "jev-latest"
        jevPreview @?= "jev-preview"
        requestIdHeader @?= "x-typesafe-request-id"
        dangerZoneImagesHeader @?= "TypeSafe-Danger-Zone-Images"
        dangerZoneLongContextHeader @?= "TypeSafe-Danger-Zone-Long-Context"
        systemOnePath @?= ["v1", "systemone"]
        modelsPath @?= ["v1", "models"]
        defaultBaseUrl @?= "https://api.typesafe.ai",
      testCase "nested objects encode in stable sorted order" $ do
        let bytes =
              """
              {"b":1,"a":{"d":2,"c":3}}
              """
        c <- either fail pure (eitherDecode @Content bytes)
        encode c @?= "{\"a\":{\"c\":3,\"d\":2},\"b\":1}"
    ]
      <> [ testCase ("reject " <> show v) $ do
             contentFromValue v @?= Nothing
             decode @Content (encode v) @?= Nothing
         | v <- [Number 1, Bool True, Null]
         ]
      <> [ testCase ("preserve " <> show v) $ do
             contentToValue <$> contentFromValue v @?= Just v
             c <- maybe (fail "bad content") pure (contentFromValue v)
             encode c @?= encode v
         | v <- [String "hi", object ["a" .= object ["b" .= (1 :: Int)]], toJSON ([1, 2] :: [Int])]
         ]
