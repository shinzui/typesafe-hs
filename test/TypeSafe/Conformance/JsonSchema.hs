-- | Test-only reader and validator for the audited OpenAPI/JSON Schema subset.
module TypeSafe.Conformance.JsonSchema where

import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.Foldable (toList)
import Data.List (nub, sort)
import Data.Maybe (fromMaybe)
import Data.Scientific qualified as Scientific
import Data.Text (Text)
import Data.Text qualified as Text

newtype Spec = Spec Value

loadSpec :: FilePath -> IO Spec
loadSpec path = do
  value <- either fail pure =<< eitherDecodeFileStrict path
  case value of
    Object _ -> pure (Spec value)
    _ -> fail "OpenAPI document must be an object"

specFromValue :: Value -> Spec
specFromValue = Spec

at :: [Text] -> Value -> Value
at [] v = v
at (k : ks) (Object o) = maybe Null (at ks) (KM.lookup (Key.fromText k) o)
at _ _ = Null

entries :: Value -> [(Text, Value)]
entries (Object o) = [(Key.toText k, v) | (k, v) <- KM.toList o]
entries _ = []

array :: Value -> [Value]
array (Array xs) = toList xs
array _ = []

textValue :: Value -> Maybe Text
textValue (String t) = Just t
textValue _ = Nothing

specVersion :: Spec -> Maybe Text
specVersion (Spec v) = textValue (at ["info", "version"] v)

operations :: Spec -> [(Text, Text, Value)]
operations (Spec v) = [(Text.toUpper method, path, op) | (path, item) <- entries (at ["paths"] v), (method, op) <- entries item, method `elem` methods]

methods :: [Text]
methods = ["get", "post", "put", "delete", "patch", "head", "options", "trace"]

specOperations :: Spec -> [(Text, Text)]
specOperations spec = [(m, p) | (m, p, _) <- operations spec]

specSchemaNames :: Spec -> [Text]
specSchemaNames (Spec v) = map fst (entries (at ["components", "schemas"] v))

lookupSchema :: Spec -> Text -> Maybe Value
lookupSchema (Spec v) name = case at ["components", "schemas"] v of
  Object o -> KM.lookup (Key.fromText name) o
  _ -> Nothing

schemaRef :: Text -> Value
schemaRef name = object ["$ref" .= ("#/components/schemas/" <> name)]

objectProperties :: Spec -> Text -> [Text]
objectProperties spec name = maybe [] (map fst . entries . at ["properties"]) (lookupSchema spec name)

requiredProperties :: Spec -> Text -> [Text]
requiredProperties spec name = maybe [] (foldMap (maybe [] pure . textValue) . array . at ["required"]) (lookupSchema spec name)

discriminatorTags :: Spec -> Text -> [Text]
discriminatorTags spec name = maybe [] (map fst . entries . at ["discriminator", "mapping"]) (lookupSchema spec name)

propertyExamples :: Spec -> Text -> [(Text, [Value])]
propertyExamples spec name = [(k, array (at ["examples"] s)) | (k, s) <- maybe [] (entries . at ["properties"]) (lookupSchema spec name)]

mediaObjects :: Spec -> [(Text, Text, Text, Text, Value)]
mediaObjects spec =
  concat
    [ [(m, p, "request", ct, media) | (ct, media) <- entries (at ["requestBody", "content"] op)]
        <> [(m, p, status, ct, media) | (status, response) <- entries (at ["responses"] op), (ct, media) <- entries (at ["content"] response)]
    | (m, p, op) <- operations spec
    ]

operationContentTypes :: Spec -> [(Text, Text, Text, Text)]
operationContentTypes spec = [(m, p, w, ct) | (m, p, w, ct, _) <- mediaObjects spec]

operationExamples :: Spec -> [(Text, Text, Text, Text, Value)]
operationExamples spec = [(m, p, w, name, at ["value"] ex) | (m, p, w, "application/json", media) <- mediaObjects spec, (name, ex) <- entries (at ["examples"] media)]

operationParameters :: Spec -> [(Text, Text, Text, Text, Value)]
operationParameters spec = [(m, p, fromMaybe "" (textValue (at ["name"] param)), fromMaybe "" (textValue (at ["in"] param)), at ["schema"] param) | (m, p, op) <- operations spec, param <- array (at ["parameters"] op)]

operationSecurity :: Spec -> [(Text, Text, Value)]
operationSecurity spec = [(m, p, at ["security"] op) | (m, p, op) <- operations spec]

securitySchemes :: Spec -> Value
securitySchemes (Spec v) = at ["components", "securitySchemes"] v

serverUrls :: Spec -> [Text]
serverUrls (Spec v) = [url | s <- array (at ["servers"] v), Just url <- [textValue (at ["url"] s)]]

schemaRoots :: Spec -> [Value]
schemaRoots spec@(Spec v) =
  map snd (entries (at ["components", "schemas"] v))
    <> [s | (_, _, _, _, s) <- operationParameters spec]
    <> [at ["schema"] media | (_, _, _, _, media) <- mediaObjects spec]

schemaNodes :: Value -> [Value]
schemaNodes value@(Object o) =
  value
    : concat
      [ case Key.toText k of
          "properties" -> concatMap (schemaNodes . snd) (entries v)
          "additionalProperties" -> schemaNodes v
          "items" -> schemaNodes v
          "anyOf" -> concatMap schemaNodes (array v)
          "oneOf" -> concatMap schemaNodes (array v)
          "contentSchema" -> schemaNodes v
          _ -> []
      | (k, v) <- KM.toList o
      ]
schemaNodes v = [v]

supportedKeywords :: [Text]
supportedKeywords = ["$ref", "type", "const", "enum", "properties", "required", "additionalProperties", "items", "minItems", "maxItems", "minProperties", "maxProperties", "anyOf", "oneOf", "title", "description", "examples", "default", "discriminator", "x-accepts", "contentMediaType", "contentSchema"]

unsupportedKeywords :: Spec -> [Text]
unsupportedKeywords spec = sort . nub $ [k | root <- schemaRoots spec, node <- schemaNodes root, (k, _) <- entries node, k `notElem` supportedKeywords]

unsupportedOpenApiFields :: Spec -> [Text]
unsupportedOpenApiFields spec@(Spec root) =
  check "root" ["openapi", "info", "paths", "components", "servers"] root
    <> check "info" ["title", "description", "version"] (at ["info"] root)
    <> check "components" ["schemas", "securitySchemes"] (at ["components"] root)
    <> ["root missing " <> k | k <- ["openapi", "info", "paths", "components"], at [k] root == Null]
    <> ["components.schemas must be a nonempty object" | null (specSchemaNames spec)]
    <> ["unsupported OpenAPI version" | at ["openapi"] root /= String "3.1.0"]
    <> concat [check ("paths." <> p) methods item | (p, item) <- entries (at ["paths"] root)]
    <> concat [auditOperation m p op | (m, p, op) <- operations spec]
    <> concat
      [ check (m <> " " <> p <> " " <> w <> " " <> ct) ["schema", "examples", "encoding"] media
          <> concat [check ("example." <> name) ["summary", "description", "value"] ex | (name, ex) <- entries (at ["examples"] media)]
      | (m, p, w, ct, media) <- mediaObjects spec
      ]
    <> concat
      [ check ("securitySchemes." <> name) ["type", "scheme", "description"] s
          <> ["unsupported security scheme " <> name | at ["type"] s /= String "http" || at ["scheme"] s /= String "bearer"]
      | (name, s) <- entries (securitySchemes spec)
      ]
  where
    check path allowed value =
      [path <> "." <> k | (k, _) <- entries value, k `notElem` allowed]
        <> [path <> " must be an object" | case value of Object _ -> False; _ -> True]
    auditOperation m p op =
      let prefix = m <> " " <> p
       in check prefix ["summary", "description", "operationId", "parameters", "requestBody", "responses", "security"] op
            <> concat
              [ check (prefix <> " parameter") ["name", "in", "description", "schema", "example", "required"] param
                  <> [prefix <> " unsupported parameter location" | at ["in"] param /= String "header"]
              | param <- array (at ["parameters"] op)
              ]
            <> [prefix <> " unknown security scheme " <> name | security <- array (at ["security"] op), (name, _) <- entries security, name `notElem` map fst (entries (securitySchemes spec))]
            <> (if at ["requestBody"] op == Null then [] else check (prefix <> " requestBody") ["content", "required", "description"] (at ["requestBody"] op))
            <> concat [check (prefix <> " response " <> status) ["description", "content"] response | (status, response) <- entries (at ["responses"] op)]

validate :: Spec -> Value -> Value -> [String]
validate spec = go (0 :: Int) "$"
  where
    go depth path schema value
      | depth > 64 = [path <> ": schema reference recursion limit exceeded"]
      | otherwise = case schema of
          Bool True -> []
          Bool False -> [path <> ": no value allowed"]
          Object s -> concatMap (keyword (depth + 1) path s value) (KM.toList s)
          _ -> [path <> ": malformed schema"]
    keyword depth path s value (key, arg) =
      let recur = go depth
          err message = [path <> ": " <> message]
          count predicate message = [path <> ": " <> message | predicate]
       in case Key.toText key of
            "$ref" -> case arg of
              String ref | Just name <- Text.stripPrefix "#/components/schemas/" ref, Just target <- lookupSchema spec name -> recur path target value
              _ -> err ("unresolved reference " <> show arg)
            "type" -> case arg of
              String t -> count (not (hasType t value)) ("expected " <> Text.unpack t)
              _ -> err "malformed type"
            "const" -> count (value /= arg) "constant mismatch"
            "enum" -> case arg of
              Array values -> count (value `notElem` toList values) "enum mismatch"
              _ -> err "malformed enum"
            "properties" -> case (arg, value) of
              (Object props, Object obj) -> concat [recur (path <> "." <> Key.toString k) child v | (k, child) <- KM.toList props, Just v <- [KM.lookup k obj]]
              _ -> []
            "required" -> case (arg, value) of
              (Array names, Object obj) -> [path <> ": missing required property " <> Text.unpack name | String name <- toList names, not (KM.member (Key.fromText name) obj)]
              _ -> []
            "additionalProperties" -> case value of
              Object obj ->
                let declared = map fst (entries (at ["properties"] (Object s)))
                 in concat [recur (path <> "." <> Text.unpack k) arg v | (k, v) <- entries (Object obj), k `notElem` declared]
              _ -> []
            "items" -> case value of
              Array xs -> concat [recur (path <> "[" <> show i <> "]") arg v | (i, v) <- zip [0 :: Int ..] (toList xs)]
              _ -> []
            "minItems" -> case (arg, value) of (Number n, Array xs) -> count (fromIntegral (length xs) < n) "too few items"; _ -> []
            "maxItems" -> case (arg, value) of (Number n, Array xs) -> count (fromIntegral (length xs) > n) "too many items"; _ -> []
            "minProperties" -> case (arg, value) of (Number n, Object o) -> count (fromIntegral (KM.size o) < n) "too few properties"; _ -> []
            "maxProperties" -> case (arg, value) of (Number n, Object o) -> count (fromIntegral (KM.size o) > n) "too many properties"; _ -> []
            "anyOf" -> case arg of
              Array alts -> count (not (any (null . (\alt -> recur path alt value)) (toList alts))) "no anyOf alternative matches"
              _ -> err "malformed anyOf"
            "oneOf" -> case arg of
              Array alts -> count (length (filter (null . (\alt -> recur path alt value)) (toList alts)) /= 1) "expected exactly one oneOf alternative"
              _ -> err "malformed oneOf"
            annotation | annotation `elem` ["title", "description", "examples", "default", "discriminator", "x-accepts", "contentMediaType", "contentSchema"] -> []
            other -> err ("unsupported JSON Schema keyword " <> show other)
    hasType t v = case (t, v) of
      ("string", String _) -> True
      ("number", Number _) -> True
      ("integer", Number n) -> Scientific.isInteger n
      ("boolean", Bool _) -> True
      ("object", Object _) -> True
      ("array", Array _) -> True
      ("null", Null) -> True
      _ -> False
