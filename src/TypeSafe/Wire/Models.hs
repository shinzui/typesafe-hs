-- | Model metadata preserves release dates verbatim, with an optional day parser.
module TypeSafe.Wire.Models (ModelMetadataList (..), ModelMetadata (..), releaseDay) where

import Data.Aeson
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Calendar (Day)
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.Vector (Vector)
import GHC.Generics (Generic)
import TypeSafe.Wire.Common

-- | Wire representation of the ModelMetadataList schema.
data ModelMetadataList = ModelMetadataList
  { models :: !(Vector ModelMetadata)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON ModelMetadataList where
  toJSON x = object $ [] <> ["models" .= x.models]
  toEncoding x = pairs $ "models" .= x.models

instance FromJSON ModelMetadataList where
  parseJSON = withObject "ModelMetadataList" $ \o -> ModelMetadataList <$> o .: "models"

-- | Wire representation of the ModelMetadata schema.
data ModelMetadata = ModelMetadata
  { name :: !(ModelName),
    description :: !(Text),
    releaseDate :: !(Text)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON ModelMetadata where
  toJSON x = object $ [] <> ["name" .= x.name] <> ["description" .= x.description] <> ["release_date" .= x.releaseDate]
  toEncoding x = pairs $ "name" .= x.name <> "description" .= x.description <> "release_date" .= x.releaseDate

instance FromJSON ModelMetadata where
  parseJSON = withObject "ModelMetadata" $ \o -> ModelMetadata <$> o .: "name" <*> o .: "description" <*> o .: "release_date"

-- | Parse YYYY-MM-DD when possible; unusual dates still decode as text (R9).
releaseDay :: ModelMetadata -> Maybe Day
releaseDay m = iso8601ParseM (Text.unpack m.releaseDate)
