-- | Shared wire primitives. Import "TypeSafe.Wire" for the complete surface.
module TypeSafe.Wire.Common
  ( apiSpecVersion,
    ModelName (..),
    QuestionName (..),
    jevLatest,
    jevPreview,
    Content (..),
    contentFromValue,
    contentToValue,
    requestIdHeader,
    dangerZoneImagesHeader,
    dangerZoneLongContextHeader,
    systemOnePath,
    modelsPath,
    defaultBaseUrl,
  )
where

import Data.Aeson
import Data.String (IsString)
import Data.Text (Text)
import GHC.Generics (Generic)
import Network.HTTP.Types (HeaderName)

-- | Version label of the vendored OpenAPI document (R10).
apiSpecVersion :: Text
apiSpecVersion = "0.2.0"

-- | An open model name or alias (R8).
newtype ModelName = ModelName Text
  deriving stock (Generic, Show)
  deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

-- | An open caller-chosen question name (R8).
newtype QuestionName = QuestionName Text
  deriving stock (Generic, Show)
  deriving newtype (Eq, Ord, IsString, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

-- | Published model aliases; no behavior is inferred from them (R8).
jevLatest, jevPreview :: ModelName
jevLatest = "jev-latest"
jevPreview = "jev-preview"

-- | Content is a string, object or array, never a scalar or null (R7).
data Content = ContentText !Text | ContentObject !Object | ContentArray !Array
  deriving stock (Generic, Eq, Show)

instance ToJSON Content where
  toJSON = contentToValue
  toEncoding (ContentText t) = toEncoding t
  toEncoding (ContentObject o) = toEncoding o
  toEncoding (ContentArray a) = toEncoding a

instance FromJSON Content where
  parseJSON v = case contentFromValue v of
    Just c -> pure c
    Nothing -> fail ("expected a string, object or array, got " <> kind v)
    where
      kind (Number _) = "number"
      kind (Bool _) = "boolean"
      kind Null = "null"
      kind _ = "unsupported value"

-- | Reject values outside the content union without stringifying them (R7).
contentFromValue :: Value -> Maybe Content
contentFromValue (String t) = Just (ContentText t)
contentFromValue (Object o) = Just (ContentObject o)
contentFromValue (Array a) = Just (ContentArray a)
contentFromValue _ = Nothing

-- | Preserve the underlying JSON structure (R7).
contentToValue :: Content -> Value
contentToValue (ContentText t) = String t
contentToValue (ContentObject o) = Object o
contentToValue (ContentArray a) = Array a

-- | Response request-id header (R6).
requestIdHeader :: HeaderName
requestIdHeader = "x-typesafe-request-id"

-- | Optional image feature header (R6).
dangerZoneImagesHeader :: HeaderName
dangerZoneImagesHeader = "TypeSafe-Danger-Zone-Images"

-- | Optional long-context feature header (R6).
dangerZoneLongContextHeader :: HeaderName
dangerZoneLongContextHeader = "TypeSafe-Danger-Zone-Long-Context"

-- | System One and model-listing path segments (R6).
systemOnePath, modelsPath :: [Text]
systemOnePath = ["v1", "systemone"]
modelsPath = ["v1", "models"]

-- | Default API base URL, with no environment lookup (R6).
defaultBaseUrl :: Text
defaultBaseUrl = "https://api.typesafe.ai"
