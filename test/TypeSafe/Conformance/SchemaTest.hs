{-# LANGUAGE ExistentialQuantification #-}

module TypeSafe.Conformance.SchemaTest (tests, excludedContentTypes, setAt) where

import Control.Monad (forM_)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.Aeson.Types (parseEither)
import Data.Either (isLeft)
import Data.List (nub, sort)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Proxy (Proxy (..))
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Vector qualified as V
import Test.QuickCheck (Arbitrary, Gen, arbitrary, forAll, generate, vectorOf)
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck (counterexample, testProperty, (===))
import TypeSafe.Conformance.JsonSchema
import TypeSafe.Test.Arbitrary
import TypeSafe.Wire

data Binding
  = forall a.
    (Arbitrary a, ToJSON a, FromJSON a, Eq a, Show a) =>
    Binding Text (Proxy a) RoundTrip [FieldBinding a]

data RoundTrip = ExactRoundTrip | JsonRoundTrip

data FieldBinding a = FieldBinding Text (a -> Maybe Value)

bindings :: [Binding]
bindings =
  [ Binding "SystemOneRequest" (Proxy @SystemOneRequest) JsonRoundTrip [FieldBinding "model" (\r -> Just (toJSON r.model)), FieldBinding "state" (\r -> Just (toJSON r.state)), FieldBinding "questions" (\r -> Just (object [Key.fromText n .= q | (QuestionName n, q) <- V.toList r.questions])), FieldBinding "assets" (\r -> if Map.null r.assets then Nothing else Just (toJSON r.assets))],
    Binding "Question" (Proxy @Question) JsonRoundTrip [],
    Binding "NoulQuestion" (Proxy @NoulQuestion) ExactRoundTrip [FieldBinding "instructions" (\r -> toJSON <$> r.instructions), FieldBinding "criteria" (\r -> toJSON <$> r.criteria)],
    Binding "NoulCriteria" (Proxy @NoulCriteria) ExactRoundTrip [FieldBinding "true" (\r -> toJSON <$> r.true), FieldBinding "false" (\r -> toJSON <$> r.false)],
    Binding "ChoiceQuestion" (Proxy @ChoiceQuestion) JsonRoundTrip [FieldBinding "instructions" (\r -> toJSON <$> r.instructions), FieldBinding "criteria" (\r -> Just (object [Key.fromText k .= v | (k, v) <- V.toList r.criteria]))],
    Binding "ScoreQuestion" (Proxy @ScoreQuestion) ExactRoundTrip [FieldBinding "instructions" (\r -> toJSON <$> r.instructions), FieldBinding "criteria" (\r -> Just (toJSON r.criteria))],
    Binding "BoxQuestion" (Proxy @BoxQuestion) ExactRoundTrip [FieldBinding "instructions" (\r -> toJSON <$> r.instructions)],
    Binding "Asset" (Proxy @Asset) ExactRoundTrip [FieldBinding "format" (\r -> toJSON <$> r.format), FieldBinding "data_base64" (\r -> toJSON <$> r.dataBase64), FieldBinding "part" (\r -> toJSON <$> r.part)],
    Binding "SystemOneResponse" (Proxy @SystemOneResponse) ExactRoundTrip [FieldBinding "model" (\r -> Just (toJSON r.model)), FieldBinding "answers" (\r -> Just (toJSON r.answers)), FieldBinding "usage" (\r -> Just (toJSON r.usage))],
    Binding "Answer" (Proxy @Answer) ExactRoundTrip [],
    Binding "NoulAnswer" (Proxy @NoulAnswer) ExactRoundTrip [FieldBinding "noul" (\r -> Just (toJSON r.noul))],
    Binding "ChoiceAnswer" (Proxy @ChoiceAnswer) ExactRoundTrip [FieldBinding "choice" (\r -> Just (toJSON r.choice)), FieldBinding "confidence" (\r -> Just (toJSON r.confidence)), FieldBinding "probabilities" (\r -> Just (toJSON r.probabilities))],
    Binding "ScoreAnswer" (Proxy @ScoreAnswer) ExactRoundTrip [FieldBinding "score" (\r -> Just (toJSON r.score)), FieldBinding "confidence" (\r -> Just (toJSON r.confidence)), FieldBinding "legend" (\r -> Just (toJSON r.legend)), FieldBinding "probabilities" (\r -> Just (toJSON r.probabilities))],
    Binding "BoxAnswer" (Proxy @BoxAnswer) ExactRoundTrip [FieldBinding "box" (\r -> Just (toJSON r.box)), FieldBinding "confidence" (\r -> Just (toJSON r.confidence))],
    Binding "BoxCoordinates" (Proxy @BoxCoordinates) ExactRoundTrip [FieldBinding "top" (\r -> Just (toJSON r.top)), FieldBinding "bottom" (\r -> Just (toJSON r.bottom)), FieldBinding "left" (\r -> Just (toJSON r.left)), FieldBinding "right" (\r -> Just (toJSON r.right))],
    Binding "Usage" (Proxy @Usage) ExactRoundTrip [FieldBinding "input_tokens" (\r -> Just (toJSON r.inputTokens)), FieldBinding "output_tokens" (\r -> Just (toJSON r.outputTokens))],
    Binding "ModelMetadata" (Proxy @ModelMetadata) ExactRoundTrip [FieldBinding "name" (\r -> Just (toJSON r.name)), FieldBinding "description" (\r -> Just (toJSON r.description)), FieldBinding "release_date" (\r -> Just (toJSON r.releaseDate))],
    Binding "ModelMetadataList" (Proxy @ModelMetadataList) ExactRoundTrip [FieldBinding "models" (\r -> Just (toJSON r.models))],
    Binding "HTTPValidationError" (Proxy @HTTPValidationError) ExactRoundTrip [FieldBinding "detail" (\r -> toJSON <$> r.detail)],
    Binding "ValidationError" (Proxy @ValidationError) ExactRoundTrip [FieldBinding "loc" (\r -> Just (toJSON r.loc)), FieldBinding "msg" (\r -> Just (toJSON r.msg)), FieldBinding "type" (\r -> Just (toJSON r.type_)), FieldBinding "input" (\r -> toJSON <$> r.input), FieldBinding "ctx" (\r -> toJSON <$> r.ctx)],
    Binding "HTTPBadRequestError" (Proxy @HTTPBadRequestError) ExactRoundTrip [FieldBinding "detail" (\r -> Just (toJSON r.detail))]
  ]

excludedContentTypes :: [(Text, Text, Text, Text)]
-- Remove this exclusion when docs/plans/7-send-images-with-multipart-system-one-requests.md is accepted.
excludedContentTypes = [("POST", "/v1/systemone", "request", "multipart/form-data")]

contentErrors :: Spec -> [(Text, Text, Text, Text)]
contentErrors spec =
  [entry | entry@(_, _, _, ct) <- operationContentTypes spec, ct /= "application/json", entry `notElem` excludedContentTypes]
    <> [entry | entry <- excludedContentTypes, entry `notElem` operationContentTypes spec]

setAt :: [Text] -> Value -> Value -> Value
setAt [] replacement _ = replacement
setAt (k : ks) replacement (Object o) = Object (KM.insert (Key.fromText k) (setAt ks replacement (maybe (Object KM.empty) id (KM.lookup (Key.fromText k) o))) o)
setAt path replacement _ = setAt path replacement (Object KM.empty)

tests :: Spec -> TestTree
tests spec@(Spec root) =
  testGroup "OpenAPI conformance" $
    [ testCase "every schema is bound" $ sort [name | Binding name _ _ _ <- bindings] @?= sort (specSchemaNames spec),
      testCase "the schema validator understands every keyword in use" $ unsupportedKeywords spec @?= [],
      testCase "every OpenAPI field in use is understood" $ unsupportedOpenApiFields spec @?= [],
      testCase "every content type is bound or explicitly excluded" $ contentErrors spec @?= [],
      testCase "unknown keyword meta-test" $ do
        let mutant = specFromValue (setAt ["components", "schemas", "Usage", "properties", "input_tokens", "pattern"] (String "^a") root)
        unsupportedKeywords mutant @?= ["pattern"]
        assertBool "validator rejects unknown keyword" (not (null (validate mutant (schemaRef "Usage") (toJSON (Usage 1 2))))),
      testCase "unknown OpenAPI feature meta-test" $ do
        let mutant = specFromValue (setAt ["paths", "/v1/systemone", "post", "callbacks"] (object []) root)
        assertBool "callbacks reported" (any (Text.isInfixOf "callbacks") (unsupportedOpenApiFields mutant)),
      testCase "unknown content type meta-test" $ do
        let mutant = specFromValue (setAt ["paths", "/v1/systemone", "post", "requestBody", "content", "application/x-msgpack"] (object []) root)
        assertBool "content type rejected" (not (null (contentErrors mutant))),
      testCase "validator asserts integer, enum, bounds and required properties" $ do
        validate spec (schemaRef "Usage") (toJSON (Usage 1 2)) @?= []
        let invalid schema value = assertBool (show value) (not (null (validate spec schema value)))
        invalid (schemaRef "Usage") (object ["input_tokens" .= Number 1.5, "output_tokens" .= Number 1])
        invalid (at ["properties", "format"] (maybe Null id (lookupSchema spec "Asset"))) (String "gif")
        invalid (schemaRef "ScoreQuestion") (object ["type" .= String "score", "criteria" .= replicate 11 (String "level")])
        invalid (schemaRef "ChoiceQuestion") (object ["type" .= String "choice", "criteria" .= object []])
        invalid (schemaRef "SystemOneResponse") (object ["model" .= String "m", "usage" .= toJSON (Usage 0 0), "answers" .= object []]),
      testCase "constructors match discriminator mappings" $ do
        sort (map knownQuestionTag questionSamples) @?= sort (map Just (discriminatorTags spec "Question"))
        sort (map knownAnswerTag answerSamples) @?= sort (map Just (discriminatorTags spec "Answer"))
        eitherDecode @Question "{\"type\":\"box\"}" @?= Right (QuestionBox (BoxQuestion Nothing)),
      testProperty "unknown questions preserve their complete encoded object" $ forAll genUnknownQuestion $ \q ->
        fmap toJSON (eitherDecode @Question (encode q)) === Right (toJSON q),
      testProperty "unknown answers preserve their complete encoded object" $ forAll genUnknownAnswer $ \a ->
        fmap toJSON (eitherDecode @Answer (encode a)) === Right (toJSON a),
      testCase "constants match document" $ do
        serverUrls spec @?= [defaultBaseUrl]
        sort (nub [p | (_, p) <- specOperations spec]) @?= sort ["/" <> Text.intercalate "/" systemOnePath, "/" <> Text.intercalate "/" modelsPath]
        sort (nub [n | (_, _, n, _, _) <- operationParameters spec]) @?= ["TypeSafe-Danger-Zone-Images", "TypeSafe-Danger-Zone-Long-Context"]
    ]
      <> map (schemaTests spec) bindings
      <> [exampleTest spec m p w name value | (m, p, w, name, value) <- operationExamples spec]

schemaTests :: Spec -> Binding -> TestTree
schemaTests spec (Binding name (_ :: Proxy a) roundTrip fields) =
  testGroup (Text.unpack name) $
    [ testProperty "encoded values validate" $ \(x :: a) ->
        let errors = validate spec (schemaRef name) (toJSON x) in counterexample (unlines errors) (null errors),
      testProperty "toEncoding agrees with toJSON" $ \(x :: a) -> eitherDecode @Value (encode x) === Right (toJSON x),
      testProperty "decoding inverts encoding" $ \(x :: a) -> case roundTrip of
        ExactRoundTrip -> eitherDecode @a (encode x) === Right x
        JsonRoundTrip -> fmap toJSON (eitherDecode @a (encode x)) === Right (toJSON x)
    ]
      <> if null properties
        then []
        else
          [ testCase "emits exactly the declared properties" $ do
              samples <- generate (vectorOf 500 (arbitrary :: Gen a))
              Set.unions [Set.fromList (map fst (entries (toJSON x))) | x <- samples] @?= Set.fromList properties,
            testCase "requires the required properties and only those" $ do
              samples <- generate (vectorOf 50 (arbitrary :: Gen a))
              forM_ samples $ \x -> case toJSON x of
                Object o -> forM_ (KM.keys o) $ \key ->
                  isLeft (parseEither (parseJSON @a) (Object (KM.delete key o))) @?= (Key.toText key `elem` requiredProperties spec name)
                _ -> assertFailure "expected object",
            testCase "property names map to plain Haskell fields" $ do
              let implied = ["type" | name `elem` ["Asset", "NoulQuestion", "ChoiceQuestion", "ScoreQuestion", "BoxQuestion", "NoulAnswer", "ChoiceAnswer", "ScoreAnswer", "BoxAnswer"]]
              sort ([key | FieldBinding key _ <- fields] <> implied) @?= sort properties
              samples <- generate (vectorOf 50 (arbitrary :: Gen a))
              forM_ samples $ \x -> case toJSON x of
                Object o -> forM_ fields $ \(FieldBinding key getter) -> KM.lookup (Key.fromText key) o @?= getter x
                _ -> assertFailure "expected object",
            testCase "property examples validate and assembled objects decode" $ do
              let schema = maybe Null id (lookupSchema spec name)
                  examples = propertyExamples spec name
              forM_ examples $ \(key, values) -> forM_ values $ \value -> validate spec (at ["properties", key] schema) value @?= []
              let first = [(Key.fromText key, v) | (key, v : _) <- examples]
              if all (\key -> KM.member (Key.fromText key) (KM.fromList first)) (requiredProperties spec name)
                then do
                  let value = Object (KM.fromList first)
                  validate spec (schemaRef name) value @?= []
                  case parseEither (parseJSON @a) value of
                    Left err -> assertFailure err
                    Right _ -> pure ()
                else pure ()
          ]
  where
    properties = objectProperties spec name

exampleTest :: Spec -> Text -> Text -> Text -> Text -> Value -> TestTree
exampleTest spec method path where_ name value = testCase (Text.unpack (method <> " " <> path <> " " <> where_ <> " example " <> name)) $ do
  let schemas = [at ["schema"] media | (m, p, w, "application/json", media) <- mediaObjects spec, m == method, p == path, w == where_]
  case schemas of
    [schema] -> do
      validate spec schema value @?= []
      case at ["$ref"] schema of
        String ref | Just schemaName <- Text.stripPrefix "#/components/schemas/" ref -> do
          let matching = [binding | binding@(Binding n _ _ _) <- bindings, n == schemaName]
          case matching of
            [Binding _ (_ :: Proxy a) _ _] -> case parseEither (parseJSON @a) value of
              Left err -> assertFailure err
              Right decoded -> toJSON decoded @?= value
            _ -> assertFailure ("unbound example schema " <> Text.unpack schemaName)
        _ -> assertFailure "example schema must be a component reference"
    _ -> assertFailure "example has no unique media schema"

questionSamples :: [Question]
questionSamples = [QuestionNoul (NoulQuestion Nothing Nothing), QuestionChoice (ChoiceQuestion Nothing (V.singleton ("a", Nothing))), QuestionScore (ScoreQuestion Nothing (ContentText "level" :| [])), QuestionBox (BoxQuestion Nothing)]

answerSamples :: [Answer]
answerSamples = [AnswerNoul (NoulAnswer 0), AnswerChoice (ChoiceAnswer "a" 0 Map.empty), AnswerScore (ScoreAnswer 0 0 Map.empty Map.empty), AnswerBox (BoxAnswer (BoxCoordinates 0 1 0 1) Nothing)]

encodedTag :: (ToJSON a) => a -> Maybe Text
encodedTag value = textValue (at ["type"] (toJSON value))

knownQuestionTag :: Question -> Maybe Text
knownQuestionTag q = case q of
  QuestionNoul a -> encodedTag a
  QuestionChoice a -> encodedTag a
  QuestionScore a -> encodedTag a
  QuestionBox a -> encodedTag a
  QuestionOther _ _ -> Nothing

knownAnswerTag :: Answer -> Maybe Text
knownAnswerTag a = case a of
  AnswerNoul x -> encodedTag x
  AnswerChoice x -> encodedTag x
  AnswerScore x -> encodedTag x
  AnswerBox x -> encodedTag x
  AnswerOther _ _ -> Nothing
