module Main (main) where

import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)
import Test.Tasty
import TypeSafe.Conformance.JsonSchema (loadSpec)
import TypeSafe.Conformance.OperationsTest qualified
import TypeSafe.Conformance.SchemaTest qualified
import TypeSafe.ReadmeExampleTest qualified
import TypeSafe.SpecVersionTest qualified
import TypeSafe.V1Test qualified
import TypeSafe.Wire.CommonTest qualified
import TypeSafe.Wire.RequestTest qualified
import TypeSafe.Wire.ResponseTest qualified

main :: IO ()
main = do
  spec <- loadSpec . fromMaybe "spec/openapi.json" =<< lookupEnv "TYPESAFE_OPENAPI_SPEC"
  defaultMain $
    testGroup
      "typesafe-hs"
      [ TypeSafe.SpecVersionTest.tests spec,
        TypeSafe.ReadmeExampleTest.tests,
        TypeSafe.Conformance.SchemaTest.tests spec,
        TypeSafe.Conformance.OperationsTest.tests spec,
        TypeSafe.V1Test.tests,
        TypeSafe.Wire.CommonTest.tests,
        TypeSafe.Wire.RequestTest.tests,
        TypeSafe.Wire.ResponseTest.tests
      ]
