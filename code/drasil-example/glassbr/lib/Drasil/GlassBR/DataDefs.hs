module Drasil.GlassBR.DataDefs {- temporarily export everything-}
{- (aspRat, dataDefs, dimLL, qDefns, glaTyFac,
  hFromt, loadDF, nonFL, risk, standOffDis, strDisFac, tolPre, tolStrDisFac,
  eqTNTWDD, calofCapacity, calofDemand, pbTolUsr, qRef,configFp)-}
  where

import Control.Lens ((^.))
import Language.Drasil
import Prelude hiding (log, exp, sqrt)
import Theory.Drasil (DataDefinition, ddE)
import SysInfo.Drasil
import qualified Language.Drasil.Sentence.Combinators as S

import Data.Drasil.Concepts.Documentation (datum, user)
import Data.Drasil.Concepts.Math (parameter)
import Data.Drasil.Concepts.PhysicalProperties (dimension)

import Data.Drasil.Citations (campidelli)

import Drasil.GlassBR.Assumptions (assumpSV, assumpLDFC)
import Drasil.GlassBR.Concepts (annealed, fullyT, glass, heatS)
import Drasil.GlassBR.Figures (demandVsSDFig, dimlessloadVsARFig)
import Drasil.GlassBR.References (astm2009, beasonEtAl1998)
import Drasil.GlassBR.Unitals (actualThicknesses, aspectRatio, charWeight,
  demand, demandq, dimlessLoad, eqTNTWeight, gTF, glassType, glassTypeCon,
  glassTypeFactors, lDurFac, lRe, loadDur, loadSF, minThick, modElas, nomThick,
  nominalThicknesses, nonFactorL, pbTol, plateLen, plateWidth, probBr, riskFun,
  sdfTol, sdx, sdy, sdz, sflawParamK, sflawParamM, standOffDist, stressDistFac,
  tNT, tolLoad, interpY, interpZ)

----------------------
-- DATA DEFINITIONS --
----------------------

dataDefs :: [DataDefinition]
dataDefs = [loadDF, standOffDis, eqTNTWDD, calofDemand]

{--}

loadDFEq :: Expr
loadDFEq = (sy loadDur $/ exactDbl 60) $^ (sy sflawParamM $/ exactDbl 16)

loadDFQD :: SimpleQDef
loadDFQD = mkQuantDef lDurFac loadDFEq

loadDF :: DataDefinition
loadDF = ddE loadDFQD [dRef astm2009] Nothing "loadDurFactor"
  [stdVals [loadDur, sflawParamM], ldfConst]

{--}

standOffDisEq :: Expr
standOffDisEq = sqrt (square (sy sdx) `addRe` square (sy sdy) `addRe` square (sy sdz))

standOffDisQD :: SimpleQDef
standOffDisQD = mkQuantDef standOffDist standOffDisEq

standOffDis :: DataDefinition
standOffDis = ddE standOffDisQD [dRef astm2009] Nothing "standOffDist" []

{--}

eqTNTWEq :: Expr
eqTNTWEq = mulRe (sy charWeight) (sy tNT)

eqTNTWQD :: SimpleQDef
eqTNTWQD = mkQuantDef eqTNTWeight eqTNTWEq

eqTNTWDD :: DataDefinition
eqTNTWDD = ddE eqTNTWQD [dRef astm2009] Nothing "eqTNTW" []

{--}

calofDemandEq :: Expr
calofDemandEq = apply interpY [str "TSD.txt", sy standOffDist, sy eqTNTWeight]

calofDemandQD :: SimpleQDef
calofDemandQD = mkQuantDef demand calofDemandEq

calofDemand :: DataDefinition
calofDemand = ddE calofDemandQD [dRef astm2009] Nothing "calofDemand" [calofDemandDesc]

--Additional Notes--
calofDemandDesc :: Sentence
calofDemandDesc =
  foldlSent [ch demand `sC` EmptyS `S.or_` phrase demandq `sC` EmptyS `S.isThe`
  (demandq ^. defn), S "obtained from", refS demandVsSDFig,
  S "by interpolation using", phrase standOffDist, sParen (ch standOffDist)
  `S.and_` ch eqTNTWeight, S "as" +:+. plural parameter, ch eqTNTWeight,
  S "is defined in" +:+. refS eqTNTWDD, ch standOffDist `S.isThe`
  phrase standOffDist, S "as defined in", refS standOffDis]

aGrtrThanB :: Sentence
aGrtrThanB = ch plateLen `S.and_` ch plateWidth `S.are` (plural dimension `S.the_ofThe` S "plate") `sC`
  S "where" +:+. sParen (eS rel)
  where
    rel :: ModelExpr
    rel = sy plateLen $>= sy plateWidth

anGlass :: Sentence
anGlass = getAcc annealed `S.is` phrase annealed +:+. phrase glass

ftGlass :: Sentence
ftGlass = getAcc fullyT `S.is` phrase fullyT +:+. phrase glass

hMin :: Sentence
hMin = ch nomThick `S.is` S "a function that maps from the nominal thickness"
  +:+. (sParen (ch minThick) `S.toThe` phrase minThick)

hsGlass :: Sentence
hsGlass = getAcc heatS `S.is` phrase heatS +:+. phrase glass

ldfConst :: Sentence
ldfConst = ch lDurFac `S.is` S "assumed to be constant" +:+. fromSource assumpLDFC

lrCap :: Sentence
lrCap = ch lRe +:+. S "is also called capacity"

pbTolUsr :: Sentence
pbTolUsr = ch pbTol `S.is` S "entered by the" +:+. phrase user

qRef :: Sentence
qRef = ch demand `S.isThe` (demandq ^. defn) `sC` S "as given in" +:+. refS calofDemand

ldfRef :: Sentence
ldfRef = definedIn  loadDF

-- List of Configuration Files necessary for DataDefs.hs
configFp :: [String]
configFp = ["SDF.txt", "TSD.txt"]

--- Helpers
interpolating :: (HasUID s, HasSymbol s, Referable f, HasShortName f) => s -> f -> Sentence
interpolating s f = foldlSent [ch s `S.is` S "obtained by interpolating from",
  plural datum, S "shown" `S.in_` refS f]

stdVals :: (HasSymbol s, HasUID s) => [s] -> Sentence
stdVals s = foldlList Comma List (map ch s) +:+ sent +:+. refS assumpSV
  where sent = case s of [ ]   -> error "stdVals needs quantities"
                         [_]   -> S "comes from"
                         (_:_) -> S "come from"
