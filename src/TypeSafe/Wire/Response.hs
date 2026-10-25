-- | Lossless success-response codecs. Semantic validation belongs to callers.
module TypeSafe.Wire.Response
  ( SystemOneResponse (..),
    Answer (..),
    NoulAnswer (..),
    ChoiceAnswer (..),
    ScoreAnswer (..),
    BoxAnswer (..),
    BoxCoordinates (..),
    Usage (..),
    decodeSystemOneResponse,
    finiteDouble,
    unitInterval,
  )
where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.ByteString.Lazy (ByteString)
import Data.Map.Strict (Map)
import Data.Scientific (Scientific, toBoundedRealFloat)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import TypeSafe.Wire.Common
import TypeSafe.Wire.Internal.Number

requireTag :: Text -> Object -> Parser ()
requireTag expected o = do
  tag <- o .: "type"
  unless (tag == expected) (fail "unexpected answer discriminator")

-- | Wire representation of the SystemOneResponse schema.
data SystemOneResponse = SystemOneResponse
  { model :: !(ModelName),
    answers :: !(Map QuestionName Answer),
    usage :: !(Usage)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON SystemOneResponse where
  toJSON x = object $ [] <> ["model" .= x.model] <> ["answers" .= x.answers] <> ["usage" .= x.usage]
  toEncoding x = pairs $ "model" .= x.model <> "answers" .= x.answers <> "usage" .= x.usage

instance FromJSON SystemOneResponse where
  parseJSON = withObject "SystemOneResponse" $ \o -> SystemOneResponse <$> o .: "model" <*> o .: "answers" <*> o .: "usage"

-- | Known variants and complete unknown objects for forward compatibility.
data Answer
  = AnswerNoul !NoulAnswer
  | AnswerChoice !ChoiceAnswer
  | AnswerScore !ScoreAnswer
  | AnswerBox !BoxAnswer
  | AnswerOther !Text !Object
  deriving stock (Generic, Eq, Show)

instance ToJSON Answer where
  toJSON (AnswerNoul a) = toJSON a
  toJSON (AnswerChoice a) = toJSON a
  toJSON (AnswerScore a) = toJSON a
  toJSON (AnswerBox a) = toJSON a
  toJSON (AnswerOther tag o) = Object (KeyMap.insert "type" (String tag) o)
  toEncoding (AnswerNoul a) = toEncoding a
  toEncoding (AnswerChoice a) = toEncoding a
  toEncoding (AnswerScore a) = toEncoding a
  toEncoding (AnswerBox a) = toEncoding a
  toEncoding (AnswerOther tag o) = toEncoding (KeyMap.insert "type" (String tag) o)

instance FromJSON Answer where
  parseJSON v =
    withObject
      "Answer"
      ( \o -> do
          tag <- o .: "type"
          case tag of
            "noul" -> AnswerNoul <$> parseJSON v
            "choice" -> AnswerChoice <$> parseJSON v
            "score" -> AnswerScore <$> parseJSON v
            "box" -> AnswerBox <$> parseJSON v
            _ -> pure (AnswerOther tag o)
      )
      v

-- | Wire representation of the NoulAnswer schema.
data NoulAnswer = NoulAnswer
  { noul :: !(Scientific)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON NoulAnswer where
  toJSON x = object $ ["type" .= ("noul" :: Text)] <> ["noul" .= x.noul]
  toEncoding x = pairs $ "type" .= ("noul" :: Text) <> "noul" .= x.noul

instance FromJSON NoulAnswer where
  parseJSON = withObject "NoulAnswer" $ \o -> requireTag "noul" o *> (NoulAnswer <$> o .: "noul")

-- | Wire representation of the ChoiceAnswer schema.
data ChoiceAnswer = ChoiceAnswer
  { choice :: !(Text),
    confidence :: !(Scientific),
    probabilities :: !(Map Text Scientific)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON ChoiceAnswer where
  toJSON x = object $ ["type" .= ("choice" :: Text)] <> ["choice" .= x.choice] <> ["confidence" .= x.confidence] <> ["probabilities" .= x.probabilities]
  toEncoding x = pairs $ "type" .= ("choice" :: Text) <> "choice" .= x.choice <> "confidence" .= x.confidence <> "probabilities" .= x.probabilities

instance FromJSON ChoiceAnswer where
  parseJSON = withObject "ChoiceAnswer" $ \o -> requireTag "choice" o *> (ChoiceAnswer <$> o .: "choice" <*> o .: "confidence" <*> o .: "probabilities")

-- | Wire representation of the ScoreAnswer schema.
data ScoreAnswer = ScoreAnswer
  { score :: !(Scientific),
    confidence :: !(Scientific),
    legend :: !(Map Text Content),
    probabilities :: !(Map Text Scientific)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON ScoreAnswer where
  toJSON x = object $ ["type" .= ("score" :: Text)] <> ["score" .= x.score] <> ["confidence" .= x.confidence] <> ["legend" .= x.legend] <> ["probabilities" .= x.probabilities]
  toEncoding x = pairs $ "type" .= ("score" :: Text) <> "score" .= x.score <> "confidence" .= x.confidence <> "legend" .= x.legend <> "probabilities" .= x.probabilities

instance FromJSON ScoreAnswer where
  parseJSON = withObject "ScoreAnswer" $ \o -> requireTag "score" o *> (ScoreAnswer <$> o .: "score" <*> o .: "confidence" <*> o .: "legend" <*> o .: "probabilities")

-- | Wire representation of the BoxAnswer schema.
data BoxAnswer = BoxAnswer
  { box :: !(BoxCoordinates),
    confidence :: !(Maybe Scientific)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON BoxAnswer where
  toJSON x = object $ ["type" .= ("box" :: Text)] <> ["box" .= x.box] <> ["confidence" .= x.confidence]
  toEncoding x = pairs $ "type" .= ("box" :: Text) <> "box" .= x.box <> "confidence" .= x.confidence

instance FromJSON BoxAnswer where
  parseJSON = withObject "BoxAnswer" $ \o -> requireTag "box" o *> (BoxAnswer <$> o .: "box" <*> o .: "confidence")

-- | Wire representation of the BoxCoordinates schema.
data BoxCoordinates = BoxCoordinates
  { top :: !(Scientific),
    bottom :: !(Scientific),
    left :: !(Scientific),
    right :: !(Scientific)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON BoxCoordinates where
  toJSON x = object $ [] <> ["top" .= x.top] <> ["bottom" .= x.bottom] <> ["left" .= x.left] <> ["right" .= x.right]
  toEncoding x = pairs $ "top" .= x.top <> "bottom" .= x.bottom <> "left" .= x.left <> "right" .= x.right

instance FromJSON BoxCoordinates where
  parseJSON = withObject "BoxCoordinates" $ \o -> BoxCoordinates <$> o .: "top" <*> o .: "bottom" <*> o .: "left" <*> o .: "right"

-- | Wire representation of the Usage schema.
data Usage = Usage
  { inputTokens :: !(Int),
    outputTokens :: !(Int)
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON Usage where
  toJSON x = object $ [] <> ["input_tokens" .= x.inputTokens] <> ["output_tokens" .= x.outputTokens]
  toEncoding x = pairs $ "input_tokens" .= x.inputTokens <> "output_tokens" .= x.outputTokens

instance FromJSON Usage where
  parseJSON = withObject "Usage" $ \o -> Usage <$> (o .: "input_tokens" >>= parseBoundedIntegral) <*> (o .: "output_tokens" >>= parseBoundedIntegral)

-- | Decode without converting or validating probabilities (R4, R5).
decodeSystemOneResponse :: ByteString -> Either Text SystemOneResponse
decodeSystemOneResponse = either (Left . Text.pack) Right . eitherDecode

-- | Convert to Double only if representable, rejecting overflow and underflow.
finiteDouble :: Scientific -> Either Text Double
finiteDouble n = case toBoundedRealFloat n of
  Left _ -> Left "number outside the representable Double range"
  Right d
    | isInfinite d || isNaN d -> Left "number is not finite"
    | otherwise -> Right d

-- | Consumer helper; wire decoders never call this range check.
unitInterval :: Scientific -> Either Text Double
unitInterval n
  | n < 0 || n > 1 = Left "number outside [0, 1]"
  | otherwise = finiteDouble n
