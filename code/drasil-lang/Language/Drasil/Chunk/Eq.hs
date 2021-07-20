{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}
module Language.Drasil.Chunk.Eq (QDefinition, fromEqn, fromEqn', fromEqnSt,
  fromEqnSt', mkQDefSt, mkQuantDef, mkQuantDef', ec,
  mkFuncDef, mkFuncDef', mkFuncDefByQ) where

import Control.Lens ((^.), makeLenses, view)
import Language.Drasil.Chunk.UnitDefn (unitWrapper, MayHaveUnit(getUnit), UnitDefn)

import Language.Drasil.Classes.Core (HasUID(uid), HasSymbol(symbol))
import Language.Drasil.Classes (NamedIdea(term), Idea(getA),
  IsUnit, DefiningExpr(defnExpr), Definition(defn), Quantity, HasSpace(typ),
  ConceptDomain(cdom), Display(toDispExpr))
import Language.Drasil.Chunk.Quantity (QuantityDict, mkQuant, mkQuant', qw)

import Language.Drasil.Expr.Display (defines)
import Language.Drasil.Expr (Expr(FCall, C))
import Language.Drasil.Expr.Math (sy)
import Language.Drasil.NounPhrase.Core (NP)
import Language.Drasil.Space (mkFunction, Space)
import Language.Drasil.Sentence (Sentence(EmptyS))
import Language.Drasil.Stages (Stage)
import Language.Drasil.Symbol (Symbol)
import Language.Drasil.UID (UID)

-- | A QDefinition is a 'QuantityDict' with a defining expression ('Expr'), a definition ('Sentence'), and a domain (['UID']).
data QDefinition = EC
  { _qua    :: QuantityDict
  , _defn'  :: Sentence
  , _inputs :: [UID]
  , _equat  :: Expr
  , cd      :: [UID]
  }
makeLenses ''QDefinition

-- | Finds the 'UID' of the 'QuantityDict' used to make the 'QDefinition'.
instance HasUID        QDefinition where uid = qua . uid
-- | Finds the term ('NP') of the 'QuantityDict' used to make the 'QDefinition'.
instance NamedIdea     QDefinition where term = qua . term
-- | Finds the idea contained in the 'QuantityDict' used to make the 'QDefinition'.
instance Idea          QDefinition where getA = getA . (^. qua)
-- | Finds the 'Space' of the 'QuantityDict' used to make the 'QDefinition'.
instance HasSpace      QDefinition where typ = qua . typ
-- | Finds the 'Symbol' of the 'QuantityDict' used to make the 'QDefinition'.
instance HasSymbol     QDefinition where symbol = symbol . (^. qua)
-- | Finds the definition of 'QDefinition'.
instance Definition    QDefinition where defn = defn'
-- | 'QDefinition's have a 'Quantity'.
instance Quantity      QDefinition where
-- | Finds the defining expression of 'QDefinition'.
instance DefiningExpr  QDefinition where defnExpr = equat
-- | Equal if 'UID's are equal.
instance Eq            QDefinition where a == b = (a ^. uid) == (b ^. uid)
-- | Finds the units of the 'QuantityDict' used to make the 'QDefinition'.
instance MayHaveUnit   QDefinition where getUnit = getUnit . view qua
-- | Displays the relation given by the expression in 'QDefinition'.
instance Display       QDefinition where
  toDispExpr q = f (q ^. defnExpr)
    where
      f = case q ^. inputs of
        [] -> defines (sy q)
        is -> defines (FCall (q ^. uid) (map C is) [])
-- | Finds the domain of a 'QDefinition'.
instance ConceptDomain QDefinition where cdom = cd

-- | Create a 'QDefinition' with a 'UID', term ('NP'), definition ('Sentence'), 'Symbol',
-- 'Space', unit, and defining expression.
fromEqn :: IsUnit u => String -> NP -> Sentence -> Symbol -> Space -> u -> Expr -> QDefinition
fromEqn nm desc def symb sp un expr =
  EC (mkQuant nm desc symb sp (Just $ unitWrapper un) Nothing) def [] expr []

-- | Same as 'fromEqn', but has no units.
fromEqn' :: String -> NP -> Sentence -> Symbol -> Space -> Expr -> QDefinition
fromEqn' nm desc def symb sp expr =
  EC (mkQuant nm desc symb sp Nothing Nothing) def [] expr []

-- | Same as 'fromEqn', but symbol depends on stage.
fromEqnSt :: IsUnit u => String -> NP -> Sentence -> (Stage -> Symbol) ->
  Space -> u -> Expr -> QDefinition
fromEqnSt nm desc def symb sp un expr =
  EC (mkQuant' nm desc Nothing sp symb (Just $ unitWrapper un)) def [] expr []

-- | Same as 'fromEqn', but symbol depends on stage and has no units.
fromEqnSt' :: String -> NP -> Sentence -> (Stage -> Symbol) -> Space -> Expr ->
  QDefinition
fromEqnSt' nm desc def symb sp expr =
  EC (mkQuant' nm desc Nothing sp symb Nothing) def [] expr []

-- | Wrapper for fromEqnSt and fromEqnSt'
mkQDefSt :: UID -> NP -> Sentence -> (Stage -> Symbol) -> Space ->
  Maybe UnitDefn -> Expr -> QDefinition
mkQDefSt u n s symb sp (Just ud) e = fromEqnSt u n s symb sp ud e
mkQDefSt u n s symb sp Nothing   e = fromEqnSt' u n s symb sp e

-- | Used to help make 'QDefinition's when 'UID', term, and 'Symbol' come from the same source.
mkQuantDef :: (Quantity c, MayHaveUnit c) => c -> Expr -> QDefinition
mkQuantDef c = mkQDefSt (c ^. uid) (c ^. term) EmptyS (symbol c) (c ^. typ) (getUnit c)

-- | Used to help make 'QDefinition's when 'UID' and 'Symbol' come from the same source, with the term separate.
mkQuantDef' :: (Quantity c, MayHaveUnit c) => c -> NP -> Expr -> QDefinition
mkQuantDef' c t = mkQDefSt (c ^. uid) t EmptyS (symbol c) (c ^. typ) (getUnit c)

-- HACK - makes the definition EmptyS !!! FIXME
-- | Smart constructor for QDefinitions. Requires a quantity and its defining 
-- equation. 
ec :: (Quantity c, MayHaveUnit c) => c -> Expr -> QDefinition
ec c eqn = EC (qw c) EmptyS [] eqn []

-- | Factored version of 'QDefinition' functions
mkFuncDef0 :: (HasUID f, HasSymbol f, HasSpace f,
                HasUID i, HasSymbol i, HasSpace i) =>
  f -> NP -> Sentence -> Maybe UnitDefn -> [i] -> Expr -> QDefinition
mkFuncDef0 f n s u is e = EC
  (mkQuant' (f ^. uid) n Nothing (mkFunction (map (^. typ) is) (f ^. typ)) (symbol f) u)
  s (map (^. uid) is) e []

-- | Create a 'QDefinition' function with a symbol, name, term, list of inputs, resultant units, and a defining Expr
mkFuncDef :: (HasUID f, HasSymbol f, HasSpace f,
               HasUID i, HasSymbol i, HasSpace i,
               IsUnit u) =>
  f -> NP -> Sentence -> u -> [i] -> Expr -> QDefinition
mkFuncDef f n s u = mkFuncDef0 f n s (Just $ unitWrapper u)

-- | Create a 'QDefinition' function with a symbol, name, term, list of inputs, and a defining Expr
mkFuncDef' :: (HasUID f, HasSymbol f, HasSpace f,
                HasUID i, HasSymbol i, HasSpace i) =>
  f -> NP -> Sentence -> [i] -> Expr -> QDefinition
mkFuncDef' f n s = mkFuncDef0 f n s Nothing

-- | Create a 'QDefinition' functions using a symbol, list of inputs, and a defining Expr
mkFuncDefByQ :: (Quantity c, MayHaveUnit c, HasSpace c,
                  Quantity i, HasSpace i) =>
  c -> [i] -> Expr -> QDefinition
mkFuncDefByQ f = case getUnit f of
  Just u  -> mkFuncDef  f (f ^. term) EmptyS u
  Nothing -> mkFuncDef' f (f ^. term) EmptyS

