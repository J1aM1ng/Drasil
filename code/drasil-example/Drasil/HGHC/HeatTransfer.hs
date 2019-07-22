module Drasil.HGHC.HeatTransfer where --whole file is used

import Language.Drasil
import Language.Drasil.ShortHands
import Theory.Drasil (DataDefinition, ddNoRefs)

import Data.Drasil.Units.Thermodynamics (heatTransferCoef)

{--}

symbols :: [QuantityDict]
symbols = htOutputs ++ htInputs

dataDefs :: [DataDefinition]
dataDefs = [htTransCladFuelDD, htTransCladCoolDD]

qDefs :: [QDefinition]
qDefs = [htTransCladFuel, htTransCladCool]

htVars :: [QuantityDict]
htVars = [cladThick, coolFilmCond, gapFilmCond, cladCond]

htInputs, htOutputs :: [QuantityDict]
htInputs = map qw htVars
htOutputs = map qw qDefs

cladThick, coolFilmCond, gapFilmCond, cladCond :: QuantityDict
cladThick    = vc "cladThick"    (cn''' "clad thickness")
  (lTau `sub` cladLabel) Real
coolFilmCond = vc "coolFilmCond" (cn' "initial coolant film conductance")
  (lH `sub` (Label "b")) Real
gapFilmCond  = vc "gapFilmCond"  (cn' "initial gap film conductance")
  (lH `sub` (Label "p")) Real
cladCond     = vc "cladCond"     (cnIES "clad conductivity") (lK `sub` cladLabel) Real

htTransCladCoolEq, htTransCladFuelEq :: Expr
htTransCladCool, htTransCladFuel :: QDefinition

---

htTransCladCoolDD :: DataDefinition
htTransCladCoolDD = ddNoRefs htTransCladCool Nothing "htTransCladCool"--Label
  []--no additional notes

htTransCladCool = fromEqn "htTransCladCool" (nounPhraseSP
  "convective heat transfer coefficient between clad and coolant")
  EmptyS (lH `sub` cladLabel) Real heatTransferCoef htTransCladCoolEq

htTransCladCoolEq =
  2 * sy cladCond * sy coolFilmCond / (2 * sy cladCond + sy cladThick 
  * sy coolFilmCond)

---

htTransCladFuelDD :: DataDefinition
htTransCladFuelDD = ddNoRefs htTransCladFuel Nothing "htTransCladFuel"--Label
  []--no additional notes

htTransCladFuel = fromEqn "htTransCladFuel" (nounPhraseSP
  "effective heat transfer coefficient between clad and fuel surface")
  EmptyS (lH `sub` (Label "g")) Real heatTransferCoef htTransCladFuelEq

htTransCladFuelEq = (2 * sy cladCond * sy gapFilmCond) / (2 * sy cladCond
  + (sy cladThick * sy gapFilmCond))

---

hghc :: CommonConcept
hghc = dcc' "hghc" (cn "tiny") "HGHC program" "HGHC"

nuclearPhys, fp :: NamedChunk
nuclearPhys = nc "nuclearPhys" (nounPhraseSP "nuclear physics")
fp = nc "fp" (cn "FP")

cladLabel :: Symbol
cladLabel = Label "c"
