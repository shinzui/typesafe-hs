module TypeSafe.Test.MockServer (Captured (..), Reply (..), withMockServer) where

import Control.Monad.IO.Class (liftIO)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.IORef
import Data.Proxy (Proxy (..))
import Network.HTTP.Types
import Network.Wai qualified as Wai
import Network.Wai.Handler.Warp (testWithApplication)
import Servant (throwError)
import Servant.Server hiding (respond)
import Servant.Server.Generic (AsServer)
import TypeSafe.V1
import TypeSafe.Wire

data Captured = Captured
  {method :: !ByteString, path :: !ByteString, headers :: ![Header], body :: !LBS.ByteString}

data Reply
  = ReplySuccess SystemOneResponse
  | ReplyError Status [Header] LBS.ByteString
  | ReplyRaw Status [Header] LBS.ByteString

withMockServer :: IORef Reply -> ModelMetadataList -> (Int -> IO (Maybe Captured) -> IO a) -> IO a
withMockServer reply models action = do
  captured <- newIORef Nothing
  let server :: Routes AsServer
      server =
        Routes
          { systemOne = \_ _ _ _ -> do
              current <- liftIO (readIORef reply)
              case current of
                ReplySuccess response -> pure response
                ReplyError status hs bytes ->
                  throwError
                    ServerError
                      { errHTTPCode = statusCode status,
                        errReasonPhrase = BS.unpack (statusMessage status),
                        errBody = bytes,
                        errHeaders = hs
                      }
                ReplyRaw _ _ _ -> throwError err500,
            models = \_ -> pure models
          }
      app request respond = do
        bytes <- Wai.strictRequestBody request
        writeIORef captured (Just (Captured (Wai.requestMethod request) (Wai.rawPathInfo request) (Wai.requestHeaders request) bytes))
        current <- readIORef reply
        case current of
          ReplyRaw status hs body -> respond (Wai.responseLBS status hs body)
          _ -> do
            chunks <- newIORef (LBS.toChunks bytes)
            let next = atomicModifyIORef' chunks $ \case
                  [] -> ([], mempty)
                  x : xs -> (xs, x)
            serve (Proxy @API) server (Wai.setRequestBodyChunks next request) respond
  testWithApplication (pure app) (\port -> action port (readIORef captured))
