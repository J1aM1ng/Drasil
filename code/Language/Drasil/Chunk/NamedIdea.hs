{-# LANGUAGE GADTs,Rank2Types #-}
module Language.Drasil.Chunk.NamedIdea where

import Language.Drasil.Chunk
import Control.Lens (Simple, Lens, (^.))

import Language.Drasil.Spec
import Language.Drasil.NounPhrase

import Prelude hiding (id)

class Chunk c => NamedIdea c where
  term :: Simple Lens c Sentence
  getA :: c -> Maybe Sentence
  --Get Abbreviation/Acronym? These might need to be separated 
  --depending on contexts, but for now I don't see a problem with it.

-- Get short form (if exists), else get term.
short :: NamedIdea c => c -> Sentence
short c = maybe (c^.term) (\x -> x) (getA c)

-- === DATA TYPES/INSTANCES === --
data NamedChunk = NC String Sentence (Maybe Sentence)
instance Eq NamedChunk where
  c1 == c2 = (c1 ^. id) == (c2 ^. id)
instance Chunk NamedChunk where
  id f (NC a b c) = fmap (\x -> NC x b c) (f a)
instance NamedIdea NamedChunk where
  term f (NC a b c) = fmap (\x -> NC a x c) (f b)
  getA (NC _ _ c) = c
  
nc :: String -> String -> NamedChunk
nc i des = NC i (S des) Nothing

ncs :: String -> Sentence -> NamedChunk
ncs i des = NC i des Nothing

nc' :: String -> String -> String -> NamedChunk
nc' i t acc = NC i (S t) (Just (S acc))

--Currently only used by RelationChunk and EqChunk
ncWDS :: String -> Sentence -> NamedChunk
ncWDS n d = NC n d Nothing

ncWDS' :: String -> Sentence -> String -> NamedChunk
ncWDS' i t a = NC i t (Just (S a))

data NPNC where
  NPNC :: String -> Sentence -> (Maybe Sentence) -> NP -> NPNC
instance Eq NPNC where
  c1 == c2 = (c1 ^. id) == (c2 ^. id)
instance Chunk NPNC where
  id f (NPNC a b c d) = fmap (\x -> NPNC x b c d) (f a)
instance NamedIdea NPNC where
  term f (NPNC a b c d) = fmap (\x -> NPNC a x c d) (f b)
  getA (NPNC _ _ c _) = c
instance NounPhrase NPNC where
  phrase (NPNC _ _ _ d) = phrase d
  plural (NPNC _ _ _ d) = plural d
  sentenceCase (NPNC _ _ _ d) = sentenceCase d
  titleCase (NPNC _ _ _ d) = titleCase d
  
npnc :: String -> NP -> NPNC
npnc i n = NPNC i (phrase n) Nothing n

npnc' :: String -> NP -> Maybe Sentence -> NPNC
npnc' i n a = NPNC i (phrase n) a n

----------------------
-- various combinators
compoundterm :: (NamedIdea c, NamedIdea d) => c -> d -> NamedChunk
compoundterm t1 t2 = NC (t1^.id ++ t2^.id) ((t1^.term) +:+ (t2^.term)) Nothing

compoundNPNC :: NPNC -> NPNC -> NPNC
compoundNPNC t1@(NPNC _ _ _ n1) t2@(NPNC _ _ _ n2) = 
  NPNC (t1^.id ++ t2^.id) ((t1^.term) +:+ (t2^.term)) Nothing 
  (compoundPhrase n1 n2) 

compoundNPNCTitle :: NPNC -> NPNC -> NPNC
compoundNPNCTitle t1@(NPNC _ _ _ n1) t2@(NPNC _ _ _ n2) = 
  NPNC (t1^.id ++ t2^.id) ((t1^.term) +:+ (t2^.term)) Nothing 
  (compoundPhrase' n1 n2)
  
-- we might want to eventually restrict the use of these via
-- some kind of type system, which asserts that:
-- 1. t1 `for` t2 means that t1 is a view of part of the reason behind t2
-- 2. t1 `of_` t2 means that t1 is a view of part of the structure of t2
for :: (NamedIdea c, NamedIdea d) => c -> d -> Sentence
for t1 t2 = (t1^.term) +:+ S "for" +:+ (t2^.term)

of_ :: (NamedIdea c, NamedIdea d) => c -> d -> Sentence
of_ t1 t2 = (t1^.term) +:+ S "of" +:+ (t2^.term)

of' :: Sentence -> Sentence -> Sentence
of' t1 t2 = t1 +:+ S "of" +:+ t2
