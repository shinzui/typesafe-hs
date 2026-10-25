module Main (main) where

import Test.Tasty
import TypeSafe.SpecVersionTest qualified
import TypeSafe.V1Test qualified
import TypeSafe.Wire.CommonTest qualified
import TypeSafe.Wire.RequestTest qualified
import TypeSafe.Wire.ResponseTest qualified

main :: IO ()
main = do
  defaultMain $
    testGroup
      "typesafe-hs"
      [ TypeSafe.SpecVersionTest.tests,
        TypeSafe.V1Test.tests,
        TypeSafe.Wire.CommonTest.tests,
        TypeSafe.Wire.RequestTest.tests,
        TypeSafe.Wire.ResponseTest.tests
      ]
