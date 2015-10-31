-- | This module parses the options section of the Docopt source string.
-- |
-- | ```
-- |   -h --help     Show this screen.
-- |   --version     Show version.
-- |   --speed=<kn>  Speed in knots [default: 10].
-- |   --moored      Moored (anchored) mine.
-- |   --drifting    Drifting mine.
-- | ```
-- |
-- | XXX:
-- | Because of the structure of the string, lexing and parsing must be
-- | interwoven to some degree. It would be great, however to re-use the
-- | existing TokenParsers written for the usage section somehow. Maybe
-- | a `pre-lex -> lex -> parse` method is justified? Or just ignore all
-- | unknown tokens.
-- |
-- | Known tokens would be [ SOpt, LOpt, Comma, '--', ':', '[default', ']'
-- |                       , StringLiteral, NumericLiteral ]
-- |
-- | During parsing, we would look for either:
-- |
-- | [ Sopt, Comma, Lopt ]
-- | [ Sopt, Lopt ]
-- | [ Lopt ]
-- | [ -- ]
-- |
-- | All following tokens are then part of the description, mostly garbage.
-- | However, we keep an eye open for '[default' and ']' and the StringLiteral
-- | and NumericLiterals contained in it.

module Docopt.Parser.Options where

import Prelude
import Control.Lazy (defer)
import Control.Alt ((<|>))
import Control.Apply ((*>), (<*))
import Control.MonadPlus (guard)
import Data.List (List(..), some, (:), toList, length, singleton, many)
import qualified Text.Parsing.Parser as P
import qualified Text.Parsing.Parser.Combinators as P
import qualified Text.Parsing.Parser.Pos as P
import qualified Text.Parsing.Parser.String as P
import Data.Either
import Data.Maybe hiding (maybe)
import Data.Generic
import Data.String (toLower)
import Docopt.Parser.Base
import Docopt.Parser.Lexer
import Docopt.Parser.Common

data ShortOption = ShortOption Char (Maybe String)
data LongOption = LongOption String (Maybe String)
data Option = Option {
  short   :: Maybe ShortOption
, long    :: Maybe LongOption
, default :: Maybe String
}

derive instance genericOption :: Generic Option
derive instance genericShortOption :: Generic ShortOption
derive instance genericLongOption :: Generic LongOption

instance showOption      :: Show Option      where show = gShow
instance showShortOption :: Show ShortOption where show = gShow
instance showLongOption  :: Show LongOption  where show = gShow

parseOptions :: TokenParser Unit
parseOptions = do

  P.Position { column: col } <- getTokenPosition

  as <- markIndent' col do
    many $ P.try do
      -- XXX: Add scan for `[defaults: ...]`
      P.manyTill anyToken $ P.lookAhead do
        parseOptionLine
  debug as

  where

    anyName :: TokenParser String
    anyName = angleName <|> shoutName <|> name

    defaults :: TokenParser String
    defaults = do
      lsquare
      anyName >>= \n -> guard $ toLower n == "default"
      x <- P.choice
        [ colon *> P.manyTill anyToken rsquare
        , P.manyTill anyToken rsquare
        ]
      debug "x:" *> debug x
      pure "XXX"

    parseOptionLine :: TokenParser Option
    parseOptionLine = sameIndent *> do
      opt <- P.choice
        [ shortAndLong
        , onlyLong
        , onlyShort ]
      pure opt

    onlyShort :: TokenParser Option
    onlyShort = do
      short <- parseShortOption
      return $ Option {
        short:   Just short
      , long:    Nothing
      , default: Nothing }

    onlyLong :: TokenParser Option
    onlyLong = do
      long <- parseLongOption
      return $ Option {
        short:   Nothing
      , long:    Just long
      , default: Nothing }

    shortAndLong :: TokenParser Option
    shortAndLong = do
      short <- parseShortOption
      long <- P.choice
        [ P.try comma *> parseLongOption
        , parseLongOption ]
      return $ Option {
        short:   Just short
      , long:    Just long
      , default: Nothing }

    parseShortOption :: TokenParser ShortOption
    parseShortOption = do
      { flag: flag, stack: stack, arg: arg } <- sopt
      (guard $ (length stack == 0))
        P.<?> "No stacked options"
      return $ ShortOption flag arg

    parseLongOption :: TokenParser LongOption
    parseLongOption = do
      opt <- lopt
      arg <- (tryMaybe $ equal *> (shoutName <|> angleName <|> name))
      return $ LongOption opt arg