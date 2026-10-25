{-# OPTIONS_GHC -Wno-orphans #-}

-- | Schema-valid generators, separate from unknown-discriminator generators.
module TypeSafe.Test.Arbitrary (genText, genNumber, genUnknownQuestion, genUnknownAnswer) where

import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Data.Scientific (Scientific, scientific)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Vector qualified as V
import Test.QuickCheck
import TypeSafe.Wire

genText :: Gen Text
genText = Text.pack <$> resize 15 (listOf (elements (['a' .. 'z'] <> ['0' .. '9'] <> " _-.`?äöü€日本語🙂\"\\\n\t")))

genNumber :: Gen Scientific
genNumber = frequency [(4, scientific <$> choose (-10000, 10000) <*> choose (-5, 5)), (1, elements [scientific 1 400, scientific (-3) (-500)])]

optional :: Gen a -> Gen (Maybe a)
optional g = frequency [(1, pure Nothing), (2, Just <$> g)]

small :: Gen a -> Gen [a]
small g = chooseInt (0, 3) >>= flip vectorOf g

json :: Int -> Gen Value
json depth =
  oneof $
    [String <$> genText, Number <$> genNumber, Bool <$> arbitrary, pure Null]
      <> if depth <= 0 then [] else [Array . V.fromList <$> small (json (depth - 1)), Object <$> obj (depth - 1)]

obj :: Int -> Gen Object
obj depth = KM.fromList <$> small ((,) <$> (Key.fromText <$> genText) <*> json depth)

instance Arbitrary Content where
  arbitrary = oneof [ContentText <$> genText, ContentObject <$> obj 2, ContentArray . V.fromList <$> small (json 2)]

instance Arbitrary ModelName where arbitrary = ModelName <$> genText

instance Arbitrary QuestionName where arbitrary = QuestionName <$> genText

instance Arbitrary NoulCriteria where arbitrary = NoulCriteria <$> optional arbitrary <*> optional arbitrary

instance Arbitrary NoulQuestion where arbitrary = NoulQuestion <$> optional arbitrary <*> optional arbitrary

instance Arbitrary ChoiceQuestion where
  arbitrary = do
    n <- chooseInt (1, 8)
    -- Fixed distinct labels let shuffled declaration order vary independently.
    keys <- shuffle [Text.pack ("label" <> show i) | i <- [1 .. n]]
    ChoiceQuestion <$> optional arbitrary <*> (V.fromList <$> traverse (\k -> (k,) <$> optional arbitrary) keys)

instance Arbitrary ScoreQuestion where
  arbitrary = ScoreQuestion <$> optional arbitrary <*> (NE.fromList <$> (chooseInt (1, 10) >>= flip vectorOf arbitrary))

instance Arbitrary BoxQuestion where arbitrary = BoxQuestion <$> optional arbitrary

instance Arbitrary ImageFormat where arbitrary = elements [minBound .. maxBound]

instance Arbitrary Asset where arbitrary = Asset <$> optional arbitrary <*> optional genText <*> optional genText

instance Arbitrary Question where
  arbitrary = oneof [QuestionNoul <$> arbitrary, QuestionChoice <$> arbitrary, QuestionScore <$> arbitrary, QuestionBox <$> arbitrary]

instance Arbitrary SystemOneRequest where
  arbitrary = do
    n <- chooseInt (1, 4)
    keys <- shuffle [QuestionName (Text.pack ("question" <> show i)) | i <- [1 .. n]]
    qs <- V.fromList <$> traverse (\k -> (k,) <$> arbitrary) keys
    assets <- frequency [(1, pure Map.empty), (2, Map.fromList <$> traverse (\i -> (Text.pack ("asset" <> show i),) <$> arbitrary) [1 :: Int, 2])]
    SystemOneRequest <$> arbitrary <*> arbitrary <*> pure qs <*> pure assets

instance Arbitrary NoulAnswer where arbitrary = NoulAnswer <$> genNumber

instance Arbitrary ChoiceAnswer where arbitrary = ChoiceAnswer <$> genText <*> genNumber <*> (Map.fromList <$> small ((,) <$> genText <*> genNumber))

instance Arbitrary ScoreAnswer where
  arbitrary = ScoreAnswer <$> genNumber <*> genNumber <*> (Map.fromList <$> small ((,) <$> genText <*> arbitrary)) <*> (Map.fromList <$> small ((,) <$> genText <*> genNumber))

instance Arbitrary BoxCoordinates where arbitrary = BoxCoordinates <$> genNumber <*> genNumber <*> genNumber <*> genNumber

instance Arbitrary BoxAnswer where arbitrary = BoxAnswer <$> arbitrary <*> optional genNumber

instance Arbitrary Answer where
  arbitrary = oneof [AnswerNoul <$> arbitrary, AnswerChoice <$> arbitrary, AnswerScore <$> arbitrary, AnswerBox <$> arbitrary]

instance Arbitrary Usage where
  arbitrary = Usage <$> count <*> count
    where
      count = frequency [(1, pure 0), (1, pure maxBound), (4, chooseInt (0, 100000))]

instance Arbitrary SystemOneResponse where
  arbitrary = do
    n <- chooseInt (1, 4)
    answers <- traverse (\i -> (QuestionName (Text.pack ("q" <> show i)),) <$> arbitrary) [1 .. n]
    SystemOneResponse <$> arbitrary <*> pure (Map.fromList answers) <*> arbitrary

instance Arbitrary ModelMetadata where
  arbitrary = ModelMetadata <$> arbitrary <*> genText <*> elements ["2026-09-15", "2026-01-31"]

instance Arbitrary ModelMetadataList where arbitrary = ModelMetadataList . V.fromList <$> small arbitrary

instance Arbitrary LocationSegment where arbitrary = oneof [LocationField <$> genText, LocationIndex <$> arbitrary]

instance Arbitrary ValidationError where
  arbitrary = ValidationError <$> (V.fromList <$> small arbitrary) <*> genText <*> genText <*> optional genText <*> optional (obj 1)

instance Arbitrary HTTPValidationError where arbitrary = HTTPValidationError <$> optional (V.fromList <$> small arbitrary)

instance Arbitrary BadRequestDetail where arbitrary = oneof [BadRequestDetailText <$> genText, BadRequestDetailObject <$> obj 2]

instance Arbitrary HTTPBadRequestError where arbitrary = HTTPBadRequestError <$> arbitrary

genUnknownQuestion :: Gen Question
genUnknownQuestion = QuestionOther <$> elements ["future", "polygon", "rank"] <*> obj 2

genUnknownAnswer :: Gen Answer
genUnknownAnswer = AnswerOther <$> elements ["future", "polygon", "rank"] <*> obj 2
