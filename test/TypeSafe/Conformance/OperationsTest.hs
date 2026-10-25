module TypeSafe.Conformance.OperationsTest (tests) where

import Control.Exception (throwIO)
import Control.Monad (forM_)
import Data.Aeson
import Data.Aeson.Types (parseEither)
import Data.ByteString.Builder (toLazyByteString)
import Data.ByteString.Lazy qualified as LBS
import Data.Foldable (toList)
import Data.IORef
import Data.List (sort)
import Data.Sequence qualified as Seq
import Data.String (fromString)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Network.HTTP.Types
import Servant.Client.Core
import Servant.Client.Generic (genericClient)
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.Conformance.JsonSchema
import TypeSafe.V1 (Routes (..))
import TypeSafe.Wire

newtype Capture a = Capture (IORef [Request] -> LBS.ByteString -> IO a)

runCapture :: Capture a -> IORef [Request] -> LBS.ByteString -> IO a
runCapture (Capture action) = action

instance Functor Capture where
  fmap f (Capture action) = Capture $ \ref body -> f <$> action ref body

instance Applicative Capture where
  pure x = Capture $ \_ _ -> pure x
  Capture f <*> Capture x = Capture $ \ref body -> f ref body <*> x ref body

instance Monad Capture where
  Capture action >>= f = Capture $ \ref body -> action ref body >>= \x -> runCapture (f x) ref body

instance RunClient Capture where
  runRequestAcceptStatus _ request = Capture $ \ref body -> do
    modifyIORef' ref (request :)
    pure Response {responseStatusCode = status200, responseHeaders = Seq.singleton (hContentType, "application/json"), responseHttpVersion = http11, responseBody = body}
  throwClientError err = Capture $ \_ _ -> throwIO err

tests :: Spec -> TestTree
tests spec = testCase "every operation is bound with declared security, headers and JSON" $ do
  ref <- newIORef []
  let routes = genericClient @Routes @Capture
      requests = [v | ("POST", "/v1/systemone", "request", "noul", v) <- operationExamples spec]
      replies = [v | ("POST", "/v1/systemone", "200", "noul", v) <- operationExamples spec]
  requestValue <- case requests of [v] -> pure v; _ -> fail "missing noul request example"
  replyValue <- case replies of [v] -> pure v; _ -> fail "missing noul response example"
  request <- either fail pure (parseEither parseJSON requestValue)
  response <- runCapture (routes.systemOne "Bearer test-token" (Just "true") (Just "true") request) ref (encode replyValue)
  toJSON response @?= replyValue
  let models = ModelMetadataList mempty
  validate spec (schemaRef "ModelMetadataList") (toJSON models) @?= []
  runCapture (routes.models "Bearer test-token") ref (encode models) >>= (@?= models)
  captured <- readIORef ref
  let operation r = (Text.decodeUtf8 (requestMethod r), Text.decodeUtf8 (LBS.toStrict (toLazyByteString (requestPath r))))
  sort (map operation captured) @?= sort (specOperations spec)
  forM_ captured $ \r -> do
    let (method, path) = operation r
        params = [(name, location, schema) | (m, p, name, location, schema) <- operationParameters spec, m == method, p == path]
        headers = toList (requestHeaders r)
        names = [name | (name, _, _) <- params]
    lookup hAuthorization headers @?= Just "Bearer test-token"
    sort [h | (h, _) <- headers, h `notElem` [hAuthorization, hAccept]] @?= sort [fromString (Text.unpack name) | name <- names]
    [security | (m, p, security) <- operationSecurity spec, m == method, p == path] @?= [toJSON [object ["HTTPBearer" .= ([] :: [Value])]]]
    forM_ params $ \(name, location, schema) -> do
      location @?= "header"
      value <- maybe (fail ("missing header " <> Text.unpack name)) pure (lookup (fromString (Text.unpack name)) headers)
      validate spec schema (String (Text.decodeUtf8 value)) @?= []
    case requestBody r of
      Nothing -> method @?= "GET"
      Just (RequestBodyLBS bytes, media) -> do
        media @?= "application/json;charset=utf-8"
        eitherDecode @Value bytes @?= Right requestValue
      Just _ -> assertFailure "unexpected request body representation"
