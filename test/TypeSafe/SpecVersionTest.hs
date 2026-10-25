module TypeSafe.SpecVersionTest (tests) where

import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Conformance.JsonSchema (Spec, specVersion)
import TypeSafe.Wire

tests :: Spec -> TestTree
tests spec = testCase "apiSpecVersion matches loaded OpenAPI info.version" $ specVersion spec @?= Just apiSpecVersion
