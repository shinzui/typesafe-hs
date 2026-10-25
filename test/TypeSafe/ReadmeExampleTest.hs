module TypeSafe.ReadmeExampleTest (tests) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Test.Tasty
import Test.Tasty.HUnit
import TypeSafe.ReadmeExample qualified as Example
import TypeSafe.Wire

tests :: TestTree
tests =
  testGroup
    "README example"
    [ testCase "README code is byte-equal to the compiled example" $ do
        readme <- Text.readFile "README.md"
        source <- Text.readFile "test/TypeSafe/ReadmeExample.hs"
        shown <- either fail pure (between "<!-- README:BEGIN -->\n```haskell\n" "```\n<!-- README:END -->" readme)
        compiled <- either fail pure (between "-- README:BEGIN\n" "-- README:END" source)
        shown @?= compiled,
      testCase "example bytes and record-dot access" $ do
        encodeSystemOneRequest Example.request @?= "{\"model\":\"jev-latest\",\"state\":\"Checkout is unavailable.\",\"questions\":{\"urgent\":{\"type\":\"noul\",\"instructions\":\"Is service blocked?\"}}}"
        response <- either (fail . Text.unpack) pure (decodeSystemOneResponse "{\"model\":\"m\",\"answers\":{\"urgent\":{\"type\":\"noul\",\"noul\":0.83}},\"usage\":{\"input_tokens\":120,\"output_tokens\":3}}")
        response.usage.inputTokens @?= 120
    ]

between :: Text -> Text -> Text -> Either String Text
between start end input = do
  let (_, suffix) = Text.breakOn start input
  rest <- maybe (Left "missing example start marker") Right (Text.stripPrefix start suffix)
  let (body, ending) = Text.breakOn end rest
  if Text.null ending then Left "missing example end marker" else Right body
