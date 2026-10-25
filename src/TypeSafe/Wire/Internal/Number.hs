module TypeSafe.Wire.Internal.Number (parseBoundedIntegral) where

import Data.Aeson (Value, withScientific)
import Data.Aeson.Types (Parser)
import Data.Scientific (isInteger, toBoundedInteger)

parseBoundedIntegral :: Value -> Parser Int
parseBoundedIntegral = withScientific "integral Int" $ \n ->
  if isInteger n
    then maybe (fail "integer outside Int range") pure (toBoundedInteger n)
    else fail "expected an integral number"
