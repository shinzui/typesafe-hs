module Main (main) where

import Test.Tasty
import TypeSafe.SpecVersionTest qualified
import TypeSafe.Wire.CommonTest qualified
import TypeSafe.Wire.RequestTest qualified

main :: IO ()
main =
  defaultMain $
    testGroup
      "typesafe-hs"
      [ TypeSafe.SpecVersionTest.tests,
        TypeSafe.Wire.CommonTest.tests,
        TypeSafe.Wire.RequestTest.tests
      ]
