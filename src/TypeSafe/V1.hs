-- | Servant routes and a policy-free client for the System One API.
module TypeSafe.V1
  ( API,
    Routes (..),
    SystemOneEndpoint,
    ModelsEndpoint,
    Methods (..),
    DangerZone (..),
    noDangerZone,
    getClientEnv,
    makeMethods,
    ClientEnv,
    ClientError (..),
  )
where

import Control.Exception (throwIO)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Network.HTTP.Client.TLS qualified as TLS
import Servant.API
import Servant.Client
import Servant.Client.Generic (genericClientHoist)
import TypeSafe.Wire

-- | @POST /v1/systemone@ with bearer auth and optional danger-zone headers.
type SystemOneEndpoint =
  Header' '[Required, Strict] "Authorization" Text
    :> "v1"
    :> "systemone"
    :> Header' '[Optional, Strict] "TypeSafe-Danger-Zone-Images" Text
    :> Header' '[Optional, Strict] "TypeSafe-Danger-Zone-Long-Context" Text
    :> ReqBody '[JSON] SystemOneRequest
    :> Post '[JSON] SystemOneResponse

-- | @GET /v1/models@ with bearer auth.
type ModelsEndpoint =
  Header' '[Required, Strict] "Authorization" Text
    :> "v1"
    :> "models"
    :> Get '[JSON] ModelMetadataList

-- | Every API operation, with auth declared on each endpoint.
data Routes mode = Routes
  { systemOne :: mode :- SystemOneEndpoint,
    models :: mode :- ModelsEndpoint
  }
  deriving stock (Generic)

-- | The shared client/server API contract.
type API = NamedRoutes Routes

-- | Each enabled flag sends its header as @true@; disabled flags omit it.
data DangerZone = DangerZone {images :: !Bool, longContext :: !Bool}
  deriving stock (Generic, Eq, Show)

-- | Send neither danger-zone header.
noDangerZone :: DangerZone
noDangerZone = DangerZone False False

-- | Authenticated methods; failures throw unmodified 'ClientError'.
data Methods = Methods
  { createSystemOne :: SystemOneRequest -> IO SystemOneResponse,
    createSystemOneWith :: DangerZone -> SystemOneRequest -> IO SystemOneResponse,
    listModels :: IO ModelMetadataList
  }
  deriving stock (Generic)

-- | Parse a base URL and create a TLS manager with its default settings.
-- Build a 'ClientEnv' with servant-client's @mkClientEnv@ to customize the manager.
getClientEnv :: Text -> IO ClientEnv
getClientEnv url = do
  base <- parseBaseUrl (Text.unpack url)
  manager <- TLS.newTlsManagerWith TLS.tlsManagerSettings
  pure (mkClientEnv manager base)

-- | Add @Bearer <key>@ and run the routes without retries or error translation.
makeMethods :: ClientEnv -> Text -> Methods
makeMethods env key = Methods {createSystemOne, createSystemOneWith, listModels}
  where
    run :: ClientM a -> IO a
    run action = runClientM action env >>= either throwIO pure
    routes :: Routes (AsClientT IO)
    routes = genericClientHoist run
    auth = "Bearer " <> key
    flag True = Just "true"
    flag False = Nothing
    createSystemOneWith zone = routes.systemOne auth (flag zone.images) (flag zone.longContext)
    createSystemOne = createSystemOneWith noDangerZone
    listModels = routes.models auth
