-- | Pure error-body codecs and total parsing, with no status classification.
module TypeSafe.Wire.Error
  ( LocationSegment (..),
    ValidationError (..),
    HTTPValidationError (..),
    HTTPBadRequestError (..),
    BadRequestDetail (..),
    ErrorDetail (..),
    ErrorBody (..),
    parseErrorBody,
  )
where

import Data.Aeson
import Data.Aeson.Encoding qualified as Encoding
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseMaybe)
import Data.ByteString.Lazy qualified as LBS
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import Data.Vector (Vector)
import GHC.Generics (Generic)
import TypeSafe.Wire.Internal.Number

optionalPair :: (ToJSON a) => Key -> Maybe a -> Encoding.Series
optionalPair k = maybe mempty (k .=)

optionalValue :: (ToJSON a) => Key -> Maybe a -> [(Key, Value)]
optionalValue k = maybe [] (\v -> [k .= v])

-- | A field name or bounded integral array index.
data LocationSegment = LocationField !Text | LocationIndex !Int
  deriving stock (Generic, Eq, Show)

instance ToJSON LocationSegment where
  toJSON (LocationField t) = toJSON t
  toJSON (LocationIndex n) = toJSON n
  toEncoding (LocationField t) = toEncoding t
  toEncoding (LocationIndex n) = toEncoding n

instance FromJSON LocationSegment where
  parseJSON (String t) = pure (LocationField t)
  parseJSON v = LocationIndex <$> parseBoundedIntegral v

-- | Wire representation of the ValidationError schema.
data ValidationError = ValidationError
  { loc :: !(Vector LocationSegment),
    msg :: !(Text),
    type_ :: !(Text),
    input :: !(Maybe Text),
    ctx :: !(Maybe Object)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON ValidationError where
  toJSON x = object $ [] <> ["loc" .= x.loc] <> ["msg" .= x.msg] <> ["type" .= x.type_] <> optionalValue "input" x.input <> optionalValue "ctx" x.ctx
  toEncoding x = pairs $ "loc" .= x.loc <> "msg" .= x.msg <> "type" .= x.type_ <> optionalPair "input" x.input <> optionalPair "ctx" x.ctx

instance FromJSON ValidationError where
  parseJSON = withObject "ValidationError" $ \o -> ValidationError <$> o .: "loc" <*> o .: "msg" <*> o .: "type" <*> o .:! "input" <*> o .:! "ctx"

-- | Wire representation of the HTTPValidationError schema.
data HTTPValidationError = HTTPValidationError
  { detail :: !(Maybe (Vector ValidationError))
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON HTTPValidationError where
  toJSON x = object $ [] <> optionalValue "detail" x.detail
  toEncoding x = pairs $ optionalPair "detail" x.detail

instance FromJSON HTTPValidationError where
  parseJSON = withObject "HTTPValidationError" $ \o -> HTTPValidationError <$> o .:! "detail"

-- | Application error detail is either text or an arbitrary JSON object.
data BadRequestDetail = BadRequestDetailText !Text | BadRequestDetailObject !Object
  deriving stock (Generic, Eq, Show)

instance ToJSON BadRequestDetail where
  toJSON (BadRequestDetailText t) = String t
  toJSON (BadRequestDetailObject o) = Object o
  toEncoding (BadRequestDetailText t) = toEncoding t
  toEncoding (BadRequestDetailObject o) = toEncoding o

instance FromJSON BadRequestDetail where
  parseJSON (String t) = pure (BadRequestDetailText t)
  parseJSON (Object o) = pure (BadRequestDetailObject o)
  parseJSON _ = fail "expected a string or object detail"

-- | Wire representation of the HTTPBadRequestError schema.
data HTTPBadRequestError = HTTPBadRequestError
  { detail :: !(BadRequestDetail)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON HTTPBadRequestError where
  toJSON x = object $ [] <> ["detail" .= x.detail]
  toEncoding x = pairs $ "detail" .= x.detail

instance FromJSON HTTPBadRequestError where
  parseJSON = withObject "HTTPBadRequestError" $ \o -> HTTPBadRequestError <$> o .: "detail"

-- | Wire representation of the ErrorDetail schema.
data ErrorDetail = ErrorDetail
  { errorType :: !(Maybe Text),
    message :: !(Text)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON ErrorDetail where
  toJSON x = object $ [] <> optionalValue "error_type" x.errorType <> ["message" .= x.message]
  toEncoding x = pairs $ optionalPair "error_type" x.errorType <> "message" .= x.message

instance FromJSON ErrorDetail where
  parseJSON = withObject "ErrorDetail" $ \o -> ErrorDetail <$> o .:! "error_type" <*> o .: "message"

-- | Recognized body shapes, or complete JSON, text and empty fallbacks.
data ErrorBody
  = ErrorBodyValidation !HTTPValidationError
  | ErrorBodyDetail !ErrorDetail
  | ErrorBodyDetailText !Text
  | ErrorBodyJson !Value
  | ErrorBodyText !Text
  | ErrorBodyEmpty
  deriving stock (Generic, Eq, Show)

-- | Parse bytes without needing a status code. Invalid UTF-8 is replaced (R6).
parseErrorBody :: LBS.ByteString -> ErrorBody
parseErrorBody bytes
  | LBS.null bytes = ErrorBodyEmpty
  | otherwise = case eitherDecode bytes of
      Left _ -> ErrorBodyText (Text.decodeUtf8Lenient (LBS.toStrict bytes))
      Right value -> classify value
  where
    classify value@(Object o) = case KeyMap.lookup "detail" o of
      Just (Array _) | Just body <- parseMaybe parseJSON value -> ErrorBodyValidation body
      Just obj@(Object _) | Just d <- parseMaybe parseJSON obj -> ErrorBodyDetail d
      Just (String t) -> ErrorBodyDetailText t
      _ -> ErrorBodyJson value
    classify value = ErrorBodyJson value
