module Docopt.Parser.Scanner where

import Prelude
import Debug.Trace
import Control.MonadPlus (guard)
import Control.Alt ((<|>))
import Control.Apply ((*>), (<*))
import qualified Text.Parsing.Parser as P
import qualified Text.Parsing.Parser.Combinators as P
import qualified Text.Parsing.Parser.Pos as P
import qualified Text.Parsing.Parser.String as P
import Data.List (List(..), many, toList, fromList, (:), length, filter
                 , takeWhile, sort, head)
import qualified Data.Array as A
import Data.String (toLower, toCharArray, fromCharArray)
import qualified Data.String as Str
import Data.Maybe
import Data.Either
import Docopt.Parser.Base
import qualified Docopt.Parser.Lexer as Lexer
import qualified Docopt.Parser.Usage as Usage
import Docopt.Textwrap (dedent)

data Docopt = Docopt Section (List Section)
type Section = String

instance showDocopt :: Show Docopt where
  show (Docopt x xs) = "Docopt " ++ show x ++ " " ++ show xs

-- | Pre-parse the docopt string and break it into sections.
scan :: String -> Either P.ParseError Docopt
scan = (flip P.runParser docoptScanner) <<< dedent

docoptScanner :: P.Parser String Docopt
docoptScanner = do

  -- | Break the input string into sections.
  -- | A section header is defined as a line starting with a label - that is
  -- | string followed by a colon.
  P.manyTill
    P.anyChar
    ((void $ P.lookAhead sectionLabel) <|> P.eof)

  -- | Parse the usage section
  label <- sectionLabel
  guard ((toLower label) == "usage")
  usage <- fromCharArray <<< fromList <$> do
    P.manyTill
      P.anyChar
      ((void $ P.lookAhead sectionLabel) <|> P.eof)

  -- | Parse any option sections
  options <- many do
    label <- sectionLabel
    traceShowA $ toLower label
    guard $ endsWith ("options") (toLower label)
    fromCharArray <<< fromList <$> do
      P.manyTill
        P.anyChar
        ((void $ P.lookAhead sectionLabel) <|> P.eof)

  pure $ Docopt usage options

  where
    sectionLabel :: P.Parser String String
    sectionLabel = do
      many space
      name <- fromCharArray <$> do
        A.many $ P.noneOf [ '\n', '\r', ':' ]
      P.char ':'
      pure name

    endsWith :: String -> String -> Boolean
    endsWith sub s = Str.drop (Str.length s - Str.length sub) s == sub