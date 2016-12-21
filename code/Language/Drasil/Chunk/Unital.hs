{-# LANGUAGE GADTs, Rank2Types #-}
module Language.Drasil.Chunk.Unital (UnitalChunk(..), makeUC, ucFromVC) where

import Control.Lens (Simple, Lens, (^.), set)
import Prelude hiding (id)
import Language.Drasil.Chunk (Chunk(..), NamedIdea(..), SymbolForm(..), 
  VarChunk(..), makeCC, vcFromCC, Quantity(..))
import Language.Drasil.Unit (Unit(..), UnitDefn(..))
import Language.Drasil.Symbol

--BEGIN HELPER FUNCTIONS--
makeUC :: Unit u => String -> String -> Symbol -> u -> UnitalChunk
makeUC nam desc sym un = UC (vcFromCC (makeCC nam desc) sym) un

ucFromVC :: Unit u => VarChunk -> u -> UnitalChunk
ucFromVC vc un = UC vc un

qlens :: (forall c. SymbolForm c => Simple Lens c a) -> Simple Lens Q a
qlens l f (Q a) = fmap (\x -> Q (set l x a)) (f (a ^. l))

-- these don't get exported
q :: Simple Lens UnitalChunk Q
q f (UC a b) = fmap (\(Q x) -> UC x b) (f (Q a))

u :: Simple Lens UnitalChunk UnitDefn
u f (UC a b) = fmap (\(UU x) -> UC a x) (f (UU b))
--END HELPER FUNCTIONS----

-------- BEGIN DATATYPES/INSTANCES --------

-- BEGIN Q --
data Q where
  Q :: SymbolForm c => c -> Q

instance Chunk Q where 
  id = qlens id

instance NamedIdea Q where 
  term = qlens term

instance SymbolForm Q where
  symbol = qlens symbol
-- END Q ----

-- BEGIN UNITALCHUNK --
data UnitalChunk where
  UC :: (SymbolForm c, Unit u) => c -> u -> UnitalChunk

instance Chunk UnitalChunk where
  id = q . id

instance NamedIdea UnitalChunk where
  term = q . term

instance SymbolForm UnitalChunk where
  symbol = q . symbol

instance Quantity UnitalChunk where
  --DO SOMETHING
  
instance Unit UnitalChunk where
  unit = u . unit
-- END UNITALCHUNK ----
