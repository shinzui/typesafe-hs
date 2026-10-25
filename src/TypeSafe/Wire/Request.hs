-- | Ordered request codecs. Decoding objects does not preserve declaration order.
module TypeSafe.Wire.Request
  ( SystemOneRequest (..),
    Question (..),
    NoulQuestion (..),
    NoulCriteria (..),
    ChoiceQuestion (..),
    ScoreQuestion (..),
    BoxQuestion (..),
    Asset (..),
    ImageFormat (..),
    encodeSystemOneRequest,
    duplicateQuestionNames,
    duplicateChoiceLabels,
  )
where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Encoding qualified as Encoding
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.ByteString.Lazy (ByteString)
import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import GHC.Generics (Generic)
import TypeSafe.Wire.Common

-- | Questions retain caller order when encoding; decoded order is unspecified.
data SystemOneRequest = SystemOneRequest
  { model :: !ModelName,
    state :: !Content,
    questions :: !(Vector (QuestionName, Question)),
    assets :: !(Map Text Asset)
  }
  deriving stock (Generic, Eq, Show)

-- | Known variants and complete unknown objects for forward compatibility.
data Question
  = QuestionNoul !NoulQuestion
  | QuestionChoice !ChoiceQuestion
  | QuestionScore !ScoreQuestion
  | QuestionBox !BoxQuestion
  | QuestionOther !Text !Object
  deriving stock (Generic, Eq, Show)

-- | A yes/no question with optional instructions and criteria.
data NoulQuestion = NoulQuestion
  {instructions :: !(Maybe Content), criteria :: !(Maybe NoulCriteria)}
  deriving stock (Generic, Eq, Show)

-- | Optional descriptions for the true and false outcomes.
data NoulCriteria = NoulCriteria
  {true :: !(Maybe Content), false :: !(Maybe Content)}
  deriving stock (Generic, Eq, Show)

-- | Criteria retain vector order on encode; decoded order is unspecified.
data ChoiceQuestion = ChoiceQuestion
  {instructions :: !(Maybe Content), criteria :: !(Vector (Text, Maybe Content))}
  deriving stock (Generic, Eq, Show)

-- | A rating question with ordered, nonempty score levels.
data ScoreQuestion = ScoreQuestion
  {instructions :: !(Maybe Content), criteria :: !(NonEmpty Content)}
  deriving stock (Generic, Eq, Show)

-- | An image localization question with optional instructions.
data BoxQuestion = BoxQuestion {instructions :: !(Maybe Content)}
  deriving stock (Generic, Eq, Show)

-- | Image formats declared by the specification.
data ImageFormat = ImageFormatPng | ImageFormatJpg | ImageFormatJpeg
  deriving stock (Generic, Eq, Show, Enum, Bounded)

-- | Inline JSON assets; multipart transport is outside the initial release.
data Asset = Asset
  {format :: !(Maybe ImageFormat), dataBase64 :: !(Maybe Text), part :: !(Maybe Text)}
  deriving stock (Generic, Eq, Show)

optionalPair :: (ToJSON a) => Key -> Maybe a -> Encoding.Series
optionalPair k = maybe mempty (k .=)

optionalValue :: (ToJSON a) => Key -> Maybe a -> [Pair]
optionalValue k = maybe [] (\v -> [k .= v])

type Pair = (Key, Value)

requireTag :: Text -> Object -> Parser ()
requireTag expected o = do
  tag <- o .: "type"
  unless (tag == expected) (fail "unexpected question discriminator")

instance ToJSON SystemOneRequest where
  toJSON r =
    object $
      [ "model" .= r.model,
        "state" .= r.state,
        "questions" .= Object (KeyMap.fromList [(Key.fromText k, toJSON q) | (QuestionName k, q) <- Vector.toList r.questions])
      ]
        <> ["assets" .= r.assets | not (Map.null r.assets)]
  toEncoding r =
    pairs $
      "model" .= r.model
        <> "state" .= r.state
        <> Encoding.pair "questions" (pairs (foldMap (\(QuestionName k, q) -> Key.fromText k .= q) r.questions))
        <> if Map.null r.assets then mempty else "assets" .= r.assets

instance FromJSON SystemOneRequest where
  parseJSON = withObject "SystemOneRequest" $ \o ->
    SystemOneRequest
      <$> o .: "model"
      <*> o .: "state"
      <*> (Vector.fromList . Map.toList <$> o .: "questions")
      <*> o .:! "assets" .!= Map.empty

instance ToJSON Question where
  toJSON (QuestionNoul q) = toJSON q
  toJSON (QuestionChoice q) = toJSON q
  toJSON (QuestionScore q) = toJSON q
  toJSON (QuestionBox q) = toJSON q
  toJSON (QuestionOther tag o) = Object (KeyMap.insert "type" (String tag) o)
  toEncoding (QuestionNoul q) = toEncoding q
  toEncoding (QuestionChoice q) = toEncoding q
  toEncoding (QuestionScore q) = toEncoding q
  toEncoding (QuestionBox q) = toEncoding q
  toEncoding (QuestionOther tag o) = toEncoding (KeyMap.insert "type" (String tag) o)

instance FromJSON Question where
  parseJSON v =
    withObject
      "Question"
      ( \o -> do
          tag <- o .: "type"
          case tag of
            "noul" -> QuestionNoul <$> parseJSON v
            "choice" -> QuestionChoice <$> parseJSON v
            "score" -> QuestionScore <$> parseJSON v
            "box" -> QuestionBox <$> parseJSON v
            _ -> pure (QuestionOther tag o)
      )
      v

instance ToJSON NoulQuestion where
  toJSON q = object $ ["type" .= ("noul" :: Text)] <> optionalValue "instructions" q.instructions <> optionalValue "criteria" q.criteria
  toEncoding q = pairs $ "type" .= ("noul" :: Text) <> optionalPair "instructions" q.instructions <> optionalPair "criteria" q.criteria

instance FromJSON NoulQuestion where
  parseJSON = withObject "NoulQuestion" $ \o -> requireTag "noul" o *> (NoulQuestion <$> o .:? "instructions" <*> o .:? "criteria")

instance ToJSON NoulCriteria where
  toJSON c = object $ optionalValue "true" c.true <> optionalValue "false" c.false
  toEncoding c = pairs $ optionalPair "true" c.true <> optionalPair "false" c.false

instance FromJSON NoulCriteria where
  parseJSON = withObject "NoulCriteria" $ \o -> NoulCriteria <$> o .:? "true" <*> o .:? "false"

instance ToJSON ChoiceQuestion where
  toJSON q =
    object $
      ["type" .= ("choice" :: Text)]
        <> optionalValue "instructions" q.instructions
        <> ["criteria" .= Object (KeyMap.fromList [(Key.fromText k, toJSON v) | (k, v) <- Vector.toList q.criteria])]
  toEncoding q =
    pairs $
      "type" .= ("choice" :: Text)
        <> optionalPair "instructions" q.instructions
        <> Encoding.pair "criteria" (pairs (foldMap (\(k, v) -> Key.fromText k .= v) q.criteria))

instance FromJSON ChoiceQuestion where
  parseJSON = withObject "ChoiceQuestion" $ \o ->
    requireTag "choice" o
      *> ( ChoiceQuestion
             <$> o .:? "instructions"
             <*> (Vector.fromList . Map.toList <$> o .: "criteria")
         )

instance ToJSON ScoreQuestion where
  toJSON q = object $ ["type" .= ("score" :: Text)] <> optionalValue "instructions" q.instructions <> ["criteria" .= q.criteria]
  toEncoding q = pairs $ "type" .= ("score" :: Text) <> optionalPair "instructions" q.instructions <> "criteria" .= q.criteria

instance FromJSON ScoreQuestion where
  parseJSON = withObject "ScoreQuestion" $ \o -> requireTag "score" o *> (ScoreQuestion <$> o .:? "instructions" <*> o .: "criteria")

instance ToJSON BoxQuestion where
  toJSON q = object $ ["type" .= ("box" :: Text)] <> optionalValue "instructions" q.instructions
  toEncoding q = pairs $ "type" .= ("box" :: Text) <> optionalPair "instructions" q.instructions

instance FromJSON BoxQuestion where
  parseJSON = withObject "BoxQuestion" $ \o -> requireTag "box" o *> (BoxQuestion <$> o .:? "instructions")

instance ToJSON ImageFormat where
  toJSON = String . imageFormatText
  toEncoding = toEncoding . imageFormatText

instance FromJSON ImageFormat where
  parseJSON = withText "ImageFormat" $ \case
    "png" -> pure ImageFormatPng
    "jpg" -> pure ImageFormatJpg
    "jpeg" -> pure ImageFormatJpeg
    _ -> fail "expected png, jpg or jpeg"

imageFormatText :: ImageFormat -> Text
imageFormatText ImageFormatPng = "png"
imageFormatText ImageFormatJpg = "jpg"
imageFormatText ImageFormatJpeg = "jpeg"

instance ToJSON Asset where
  toJSON a =
    object $
      ["type" .= ("image" :: Text)]
        <> optionalValue "format" a.format
        <> optionalValue "data_base64" a.dataBase64
        <> optionalValue "part" a.part
  toEncoding a =
    pairs $
      "type" .= ("image" :: Text)
        <> optionalPair "format" a.format
        <> optionalPair "data_base64" a.dataBase64
        <> optionalPair "part" a.part

instance FromJSON Asset where
  parseJSON = withObject "Asset" $ \o -> do
    case KeyMap.lookup "type" o of
      Nothing -> pure ()
      Just (String "image") -> pure ()
      _ -> fail "expected image asset"
    Asset <$> o .:! "format" <*> o .:! "data_base64" <*> o .:! "part"

-- | Exact deterministic bytes used by aeson and servant's JSON renderer (R3).
encodeSystemOneRequest :: SystemOneRequest -> ByteString
encodeSystemOneRequest = Encoding.encodingToLazyByteString . toEncoding

-- | Repeated names once each, in order of first repetition; encoding keeps them.
duplicateQuestionNames :: SystemOneRequest -> [QuestionName]
duplicateQuestionNames r = duplicates (map fst (Vector.toList r.questions))

-- | Repeated choice labels once each, in order of first repetition.
duplicateChoiceLabels :: ChoiceQuestion -> [Text]
duplicateChoiceLabels q = duplicates (map fst (Vector.toList q.criteria))

duplicates :: (Ord a) => [a] -> [a]
duplicates = go Set.empty Set.empty
  where
    go _ _ [] = []
    go seen reported (x : xs)
      | Set.member x seen && Set.notMember x reported = x : go seen (Set.insert x reported) xs
      | otherwise = go (Set.insert x seen) reported xs
