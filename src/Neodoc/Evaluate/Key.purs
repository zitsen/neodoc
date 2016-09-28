-- An internal wrapper data structure to uniquely identify and preserve
-- arguments during reduction.

module Neodoc.Evaluate.Key where

import Prelude
import Data.Maybe (Maybe(..), maybe, fromMaybe)
import Data.Map as Map
import Data.Pretty (class Pretty, pretty)
import Control.Alt (alt)
import Data.Tuple (Tuple(..))
import Data.Tuple.Nested ((/\))
import Data.List (singleton, (:), fromFoldable)
import Data.String (singleton) as String
import Data.Foldable (intercalate)
import Data.Array (fromFoldable) as Array
import Data.Function (on)
import Data.String.Ext ((^=), (~~))
import Data.Set (Set)
import Data.Set as Set

import Neodoc.ArgKey (ArgKey(..))
import Neodoc.ArgKey.Class (toArgKey)
import Neodoc.Data.Description (Description(..))
import Neodoc.Data.SolvedLayout (SolvedLayoutArg(..))
import Neodoc.Evaluate.Annotate

-- A key uniquely identify an argument, which in turn may have multiple keys
-- to refer to it.
newtype Key = Key (Set ArgKey)

toKey :: WithDescription SolvedLayoutArg -> Key
toKey (x /\ mDesc) = Key (Set.fromFoldable $ go x)
  where
  go (Option a _ _) = OptionKey <$> fromMaybe (singleton a) do
    desc <- mDesc
    case desc of
      (OptionDescription as _ _ _ _) -> Just $ a : fromFoldable as
      _ -> Nothing
  go _ = singleton $ toArgKey x


instance showKey :: (Show a) => Show Key where
  show (Key keys) = "Key " <> show keys

instance prettyKey :: (Pretty a) => Pretty Key where
  pretty (Key keys) = pretty $ fromFoldable keys

instance eqKey :: Eq Key where
  eq (Key keys) (Key keys') = eq keys keys'

instance ordKey :: Ord Key where
  compare (Key keys) (Key keys') = compare keys keys'
