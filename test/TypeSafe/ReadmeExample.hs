-- README:BEGIN
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

-- README:END
