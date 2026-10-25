module TypeSafe.SpecVersionTest (tests) where

import Data.Aeson
import Data.Aeson.Types (parseEither)
import Data.Text (Text)
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Wire

tests :: TestTree
tests = testCase "apiSpecVersion matches spec/openapi.json info.version" $ do
  value <- either fail pure =<< eitherDecodeFileStrict @Value "spec/openapi.json"
  version <-
    either fail pure $
      parseEither
        ( withObject "OpenAPI" $ \o -> do
            info <- o .: "info"
            withObject "info" (.: "version") info
        )
        value
  (version :: Text) @?= apiSpecVersion
