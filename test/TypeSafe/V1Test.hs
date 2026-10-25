module TypeSafe.V1Test (tests) where

import Control.Exception (SomeException, try)
import Data.Aeson
import Data.ByteString.Char8 qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.Foldable (toList)
import Data.IORef
import Data.Proxy (Proxy (..))
import Data.Text qualified as Text
import Data.Vector qualified as Vector
import GHC.TypeLits (symbolVal)
import Network.HTTP.Types
import Servant.Client qualified as Client
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Test.MockServer
import TypeSafe.V1
import TypeSafe.Wire

modelsFixture :: ModelMetadataList
modelsFixture = ModelMetadataList (Vector.singleton (ModelMetadata "jev-latest" "Test model" "2026-09-15"))

withClient :: (Methods -> IORef Reply -> IO Captured -> IO ()) -> IO ()
withClient action = do
  response <- either fail pure =<< eitherDecodeFileStrict "test/golden/baikai-response.json"
  reply <- newIORef (ReplySuccess response)
  withMockServer reply modelsFixture $ \port readCapture -> do
    env <- getClientEnv (Text.pack ("http://127.0.0.1:" <> show port))
    let capture = readCapture >>= maybe (fail "no request captured") pure
    action (makeMethods env "test-key") reply capture

requestFixture :: IO SystemOneRequest
requestFixture = either fail pure =<< eitherDecodeFileStrict "test/golden/baikai-request.json"

tests :: TestTree
tests =
  testGroup
    "TypeSafe.V1"
    [ testCase "loopback bytes, bearer token and response" $ withClient $ \methods _ capture -> do
        request <- requestFixture
        expected <- either fail pure =<< eitherDecodeFileStrict "test/golden/baikai-response.json"
        methods.createSystemOne request >>= (@?= expected)
        seen <- capture
        seen.method @?= "POST"
        seen.path @?= "/v1/systemone"
        seen.body @?= encodeSystemOneRequest request
        lookup hAuthorization seen.headers @?= Just "Bearer test-key"
        assertBool "JSON content type" (maybe False (BS.isPrefixOf "application/json") (lookup hContentType seen.headers))
        lookup dangerZoneImagesHeader seen.headers @?= Nothing
        lookup dangerZoneLongContextHeader seen.headers @?= Nothing,
      testCase "FailureResponse preserves status, headers and exact body" $ withClient $ \methods reply _ -> do
        bytes <- LBS.readFile "test/golden/validation-error-422.json"
        writeIORef reply (ReplyError status422 [(hContentType, "application/json"), (requestIdHeader, "req_test")] bytes)
        request <- requestFixture
        result <- try @ClientError (methods.createSystemOne request)
        case result of
          Left (FailureResponse _ response) -> do
            Client.responseStatusCode response @?= status422
            lookup requestIdHeader (toList (Client.responseHeaders response)) @?= Just "req_test"
            Client.responseBody response @?= bytes
            case parseErrorBody (Client.responseBody response) of
              ErrorBodyValidation body -> case body.detail of
                Just entries -> (Vector.head entries).msg @?= "Field required"
                Nothing -> assertFailure "detail missing"
              other -> assertFailure (show other)
          other -> assertFailure (show other),
      testCase "danger-zone flags emit only requested headers" $ withClient $ \methods _ capture -> do
        request <- requestFixture
        _ <- methods.createSystemOneWith (DangerZone True False) request
        first <- capture
        lookup dangerZoneImagesHeader first.headers @?= Just "true"
        lookup dangerZoneLongContextHeader first.headers @?= Nothing
        _ <- methods.createSystemOneWith (DangerZone False True) request
        second <- capture
        lookup dangerZoneImagesHeader second.headers @?= Nothing
        lookup dangerZoneLongContextHeader second.headers @?= Just "true",
      testCase "listModels route" $ withClient $ \methods _ capture -> do
        methods.listModels >>= (@?= modelsFixture)
        seen <- capture
        seen.method @?= "GET"
        seen.path @?= "/v1/models"
        lookup hAuthorization seen.headers @?= Just "Bearer test-key",
      testCase "getClientEnv parses default URL" $ do
        env <- getClientEnv defaultBaseUrl
        Client.baseUrl env @?= Client.BaseUrl Client.Https "api.typesafe.ai" 443 "",
      testCase "getClientEnv rejects malformed URL" $ do
        result <- try @SomeException (getClientEnv "not a url")
        case result of
          Left _ -> pure ()
          Right _ -> assertFailure "invalid URL accepted",
      testCase "invalid successful response stays DecodeFailure" $ withClient $ \methods reply _ -> do
        writeIORef reply (ReplyRaw status200 [(hContentType, "application/json")] "{\"model\":\"m\",\"answers\":{}}")
        request <- requestFixture
        result <- try @ClientError (methods.createSystemOne request)
        case result of
          Left (DecodeFailure _ _) -> pure ()
          other -> assertFailure (show other),
      testCase "type-level header names match constants" $ do
        (BS.pack (symbolVal (Proxy @"TypeSafe-Danger-Zone-Images"))) @?= "TypeSafe-Danger-Zone-Images"
        (BS.pack (symbolVal (Proxy @"TypeSafe-Danger-Zone-Long-Context"))) @?= "TypeSafe-Danger-Zone-Long-Context"
        dangerZoneImagesHeader @?= "TypeSafe-Danger-Zone-Images"
        dangerZoneLongContextHeader @?= "TypeSafe-Danger-Zone-Long-Context"
    ]
