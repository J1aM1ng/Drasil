module Drasil.SSP.DataDefs (dataDefns, intrsliceF, 
  lengthLs, lengthLb, sliceWght, convertFunc1, convertFunc2,
  fixme1, fixme2) where 

import Prelude hiding (cos, sin, tan)
import Language.Drasil

-- Needed for derivations
--import Data.Drasil.SentenceStructures (eqN, foldlSentCol, foldlSP, getTandS, 
 -- ofThe', sAnd)

import Drasil.SSP.Assumptions (newA9)
import Drasil.SSP.References (chen2005, fredlund1977, karchewski2012)
import Drasil.SSP.Unitals (baseAngle, baseHydroForce, baseLngth, baseWthX, 
  dryWeight, earthqkLoadFctr, fricAngle, fs, impLoadAngle, intNormForce, 
  intShrForce, inx, inxi, inxiM1, mobShrC, normToShear,
  satWeight, scalFunc, shrResC, slcWght, 
  slipDist, slipHght, slopeDist, slopeHght, surfAngle, surfHydroForce, surfLngth, ufixme1, ufixme2, waterHght, waterWeight, watrForce)

------------------------
--  Data Definitions  --
------------------------

dataDefns :: [DataDefinition]
dataDefns = [sliceWght, baseWtrF, surfWtrF, intersliceWtrF, angleA, angleB, 
  lengthB, lengthLb, lengthLs, intrsliceF, 
  convertFunc1, convertFunc2, fixme1, fixme2]

--DD1

sliceWght :: DataDefinition
sliceWght = mkDD sliceWghtQD [fredlund1977] [{-Derivation-}] "sliceWght" []--Notes
--FIXME: fill empty lists in

sliceWghtQD :: QDefinition
sliceWghtQD = mkQuantDef slcWght slcWgtEqn

slcWgtEqn :: Expr
slcWgtEqn = (inxi baseWthX) * (case_ [case1,case2,case3])
  where case1 = (((inxi slopeHght)-(inxi slipHght ))*(sy satWeight),
          (inxi waterHght) $>= (inxi slopeHght))

        case2 = (((inxi slopeHght)-(inxi waterHght))*(sy dryWeight) +
          ((inxi waterHght)-(inxi slipHght))*(sy satWeight),
          (inxi slopeHght) $> (inxi waterHght) $> (inxi slipHght))

        case3 = (((inxi slopeHght)-(inxi slipHght ))*(sy dryWeight),
          (inxi waterHght) $<= (inxi slipHght))

--DD2

baseWtrF :: DataDefinition
baseWtrF = mkDD baseWtrFQD [fredlund1977] [{-Derivation-}] "baseWtrF"
  [makeRef2S newA9]--Notes
--FIXME: fill empty lists in

baseWtrFQD :: QDefinition
baseWtrFQD = mkQuantDef baseHydroForce bsWtrFEqn 

bsWtrFEqn :: Expr
bsWtrFEqn = (inxi baseLngth)*(case_ [case1,case2])
  where case1 = (((inxi waterHght)-(inxi slipHght))*(sy waterWeight),
          (inxi waterHght) $> (inxi slipHght))

        case2 = (0, (inxi waterHght) $<= (inxi slipHght))

--DD3

surfWtrF :: DataDefinition
surfWtrF = mkDD surfWtrFQD [fredlund1977] [{-Derivation-}] "surfWtrF"
  [makeRef2S newA9]--Notes
--FIXME: fill empty lists in

surfWtrFQD :: QDefinition
surfWtrFQD = mkQuantDef surfHydroForce surfWtrFEqn

surfWtrFEqn :: Expr
surfWtrFEqn = (inxi surfLngth)*(case_ [case1,case2])
  where case1 = (((inxi waterHght)-(inxi slopeHght))*(sy waterWeight),
          (inxi waterHght) $> (inxi slopeHght))

        case2 = (0, (inxi waterHght) $<= (inxi slopeHght))

--DD4

intersliceWtrF :: DataDefinition
intersliceWtrF = mkDD intersliceWtrFQD [fredlund1977] [{-Derivation-}] "intersliceWtrF"
  []--Notes
--FIXME: fill empty lists in

intersliceWtrFQD :: QDefinition
intersliceWtrFQD = mkQuantDef watrForce intersliceWtrFEqn

intersliceWtrFEqn :: Expr
intersliceWtrFEqn = case_ [case1,case2,case3]
  where case1 = (((inxi slopeHght)-(inxi slipHght ))$^ 2 / 2  *
          (sy satWeight) + ((inxi waterHght)-(inxi slopeHght))$^ 2 *
          (sy satWeight), (inxi waterHght) $>= (inxi slopeHght))

        case2 = (((inxi waterHght)-(inxi slipHght ))$^ 2 / 2  * (sy satWeight),
                (inxi slopeHght) $> (inxi waterHght) $> (inxi slipHght))

        case3 = (0,(inxi waterHght) $<= (inxi slipHght))

--DD5

angleA :: DataDefinition
angleA = mkDD angleAQD [fredlund1977] [{-Derivation-}] "angleA" 
  [makeRef2S newA9]--Notes
--FIXME: fill empty lists in

angleAQD :: QDefinition
angleAQD = mkQuantDef baseAngle angleAEqn

angleAEqn :: Expr
angleAEqn = (inxi slipHght - inx slipHght (-1)) /
  (inxi slipDist - inx slipDist (-1))

--DD5.5

angleB :: DataDefinition
angleB = mkDD angleBQD [fredlund1977] [{-Derivation-}] "angleB"
  [makeRef2S newA9]--Notes
--FIXME: fill empty lists in

angleBQD :: QDefinition
angleBQD = mkQuantDef surfAngle angleBEqn

angleBEqn :: Expr
angleBEqn = (inxi slopeHght - inx slopeHght (-1)) /
  (inxi slopeDist - inx slopeDist (-1))

--DD6

lengthB :: DataDefinition
lengthB = mkDD lengthBQD [fredlund1977] [{-Derivation-}] "lengthB" []--Notes
--FIXME: fill empty lists in

lengthBQD :: QDefinition
lengthBQD = mkQuantDef baseWthX lengthBEqn

lengthBEqn :: Expr
lengthBEqn = inxi slipDist - inx slipDist (-1)

--DD6.3

lengthLb :: DataDefinition
lengthLb = mkDD lengthLbQD [fredlund1977] [{-Derivation-}] "lengthLb"
  [makeRef2S newA9]--Notes
--FIXME: fill empty lists in

lengthLbQD :: QDefinition
lengthLbQD = mkQuantDef baseLngth lengthLbEqn

lengthLbEqn :: Expr
lengthLbEqn = (inxi baseWthX) * sec (inxi baseAngle)

--DD6.6

lengthLs :: DataDefinition
lengthLs = mkDD lengthLsQD [fredlund1977] [{-Derivation-}] "lengthLs"
  [makeRef2S newA9]--Notes
--FIXME: fill empty lists in

lengthLsQD :: QDefinition
lengthLsQD = mkQuantDef surfLngth lengthLsEqn

lengthLsEqn :: Expr
lengthLsEqn = (inxi baseWthX) * sec (inxi surfAngle)

--DD9

intrsliceF :: DataDefinition
intrsliceF = mkDD intrsliceFQD [chen2005] [{-Derivation-}] "intrsliceF" []--Notes
--FIXME: fill empty lists in

intrsliceFQD :: QDefinition
intrsliceFQD = mkQuantDef intShrForce intrsliceFEqn

intrsliceFEqn :: Expr
intrsliceFEqn = (sy normToShear) * (inxi scalFunc) * (inxi intNormForce)

--DD13

convertFunc1 :: DataDefinition
convertFunc1 = mkDD convertFunc1QD [chen2005, karchewski2012] [{-Derivation-}]
  "convertFunc1" []

convertFunc1QD :: QDefinition
convertFunc1QD = mkQuantDef shrResC convertFunc1Eqn

convertFunc1Eqn :: Expr
convertFunc1Eqn = (sy normToShear * inxi scalFunc * 
  (cos (inxi baseAngle)) - (sin (inxi baseAngle))) * tan (sy fricAngle) - 
  (sy normToShear * inxi scalFunc * (sin (inxi baseAngle)) + 
  (cos (inxi baseAngle))) * (sy fs)

--DD14

convertFunc2 :: DataDefinition
convertFunc2 = mkDD convertFunc2QD [chen2005, karchewski2012] [{-Derivation-}]
  "convertFunc2" []

convertFunc2QD :: QDefinition
convertFunc2QD = mkQuantDef mobShrC convertFunc2Eqn

convertFunc2Eqn :: Expr
convertFunc2Eqn = ((sy normToShear * inxi scalFunc * 
  (cos (inxi baseAngle)) - (sin (inxi baseAngle))) * tan (sy fricAngle) - 
  (sy normToShear * inxi scalFunc * (sin (inxi baseAngle)) + 
  (cos (inxi baseAngle))) * (sy fs)) / 
  (inxiM1 shrResC)


{--DD10

resShearWO :: DataDefinition
resShearWO = mkDD resShearWOQD [chen2005] resShr_deriv_ssp resShearWOL
  [makeRef2S newA3, makeRef2S newA4, makeRef2S newA5]--Notes
--FIXME: fill empty lists in

resShearWOQD :: QDefinition
resShearWOQD = mkQuantDef shearRNoIntsl resShearWOEqn

resShearWOEqn :: Expr
resShearWOEqn = (((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle)) + (inxi surfLoad) * (cos (inxi impLoadAngle))) *
  (cos (inxi baseAngle)) + (negate (sy earthqkLoadFctr) * (inxi slcWght) -
  (inxi watrForceDif) + (inxi surfHydroForce) * sin (inxi surfAngle) +
  (inxi surfLoad) * (sin (inxi impLoadAngle))) * (sin (inxi baseAngle)) -
  (inxi baseHydroForce)) * tan (inxi fricAngle) + (inxi cohesion) *
  (inxi baseWthX) * sec (inxi baseAngle)

resShr_deriv_ssp :: Derivation
resShr_deriv_ssp = weave [resShrDerivation_sentence, map E resShr_deriv_eqns_ssp]

--DD11

mobShearWO :: DataDefinition
mobShearWO = mkDD mobShearWOQD [chen2005] mobShr_deriv_ssp mobShearWOL
  [makeRef2S newA3, makeRef2S newA4, makeRef2S newA5]--Notes
--FIXME: fill empty lists in

mobShearWOQD :: QDefinition
mobShearWOQD = mkQuantDef shearFNoIntsl mobShearWOEqn

mobShearWOEqn :: Expr 
mobShearWOEqn = ((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle)) + (inxi surfLoad) * (cos (inxi impLoadAngle))) *
  (sin (inxi baseAngle)) - (negate (sy earthqkLoadFctr) * (inxi slcWght) -
  (inxi watrForceDif) + (inxi surfHydroForce) * sin (inxi surfAngle) +
  (inxi surfLoad) * (sin (inxi impLoadAngle))) * (cos (inxi baseAngle))

mobShr_deriv_ssp :: Derivation
mobShr_deriv_ssp = (weave [mobShrDerivation_sentence, map E mobShr_deriv_eqns_ssp])-}

-----------------
-- Hacks --------
-----------------

fixme1, fixme2 :: DataDefinition
fixme1 = mkDD fixme1QD [{-References-}] [{-Derivation-}] "fixme1" []--Notes
fixme2 = mkDD fixme2QD [{-References-}] [{-Derivation-}] "fixme2" []--Notes
--FIXME: fill empty lists in

fixme1QD :: QDefinition
fixme1QD = ec ufixme1 (inxi intNormForce + inxiM1 intNormForce)

fixme2QD :: QDefinition
fixme2QD = ec ufixme2 (inxi watrForce + inxiM1 watrForce)

--------------------------
-- Derivation Sentences --
--------------------------

-- FIXME: move derivations with the appropriate data definition

{-resShr_deriv_sentences_ssp_s1 :: [Sentence]
resShr_deriv_sentences_ssp_s1 = [S "The", phrase shrResI, S "of a slice is", 
  S "defined as", ch shrResI, S "in" +:+. makeRef2S genDef3Label, S "The",
  phrase nrmFSubWat, S "in the", phrase equation, S "for", ch shrResI,
  S "of the soil is defined in the perpendicular force equilibrium",
  S "of a slice from", makeRefS genDef2Label `sC` S "using the", getTandS nrmFSubWat,
  S "of", makeRef2S effStress, S "shown in", eqN 1]

resShr_deriv_sentences_ssp_s2 :: [Sentence]
resShr_deriv_sentences_ssp_s2 = [plural value `ofThe'` S "interslice forces",
  ch intNormForce `sAnd` ch intShrForce, S "in the", phrase equation,
  S "are unknown, while the other", plural value,
  S "are found from the physical force", plural definition, S "of",
  makeRef2S sliceWght, S "to" +:+. makeRef2S lengthLs,
  S "Consider a force equilibrium without the affect of interslice forces" `sC`
  S "to obtain a solvable value as done for", ch nrmFNoIntsl, S "in", eqN 2]

resShr_deriv_sentences_ssp_s3 :: [Sentence]
resShr_deriv_sentences_ssp_s3 = [S "Using", ch nrmFNoIntsl `sC` S "a", phrase shearRNoIntsl,
  shearRNoIntsl ^. defn, S "can be solved for in terms of all known",
  plural value, S "as done in", eqN 3]

resShr_deriv_sentences_ssp_s4 :: [Sentence]
resShr_deriv_sentences_ssp_s4 = [S "This can be further simplified by considering assumptions",
  makeRef2S newA10, S "and", makeRef2S newA12 `sC`
  S "which state that the seismic coefficient and the external force" `sC` S "respectively"
  `sC` S "are0", S "Removing seismic and external forces yields ", eqN 4]

resShrDerivation_sentence :: [Sentence]
resShrDerivation_sentence = map foldlSentCol [resShr_deriv_sentences_ssp_s1, resShr_deriv_sentences_ssp_s2,
  resShr_deriv_sentences_ssp_s3, resShr_deriv_sentences_ssp_s4]

resShr_deriv_eqns_ssp :: [Expr]
resShr_deriv_eqns_ssp = [eq1, eq2, eq3, eq8]

eq1, eq2, eq3, eq8 :: Expr
eq1 = (inxi nrmFSubWat) $= eqlExpr cos sin (\x y -> x -
  inxiM1 intShrForce + inxi intShrForce + y) - inxi baseHydroForce

eq2 = (inxi nrmFNoIntsl) $= (((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle)) + (inxi surfLoad) * (cos (inxi impLoadAngle))) *
  (cos (inxi baseAngle)) + (negate (sy earthqkLoadFctr) * (inxi slcWght) -
  (inxi watrForce) + (inxiM1 watrForce) + (inxi surfHydroForce) *
  sin (inxi surfAngle) + (inxi surfLoad) * (sin (inxi impLoadAngle))) *
  (sin (inxi baseAngle)) - (inxi baseHydroForce))

eq3 = inxi shearRNoIntsl $= (inxi nrmFNoIntsl) * tan (inxi fricAngle) +
  (inxi cohesion) * (inxi baseWthX) * sec (inxi baseAngle) $=
  (((inxi slcWght) + (inxi surfHydroForce) * (cos (inxi surfAngle)) +
  (inxi surfLoad) * (cos (inxi impLoadAngle))) * (cos (inxi baseAngle)) +
  (negate (sy earthqkLoadFctr) * (inxi slcWght) - (inxi watrForceDif) +
  (inxi surfHydroForce) * sin (inxi surfAngle) + (inxi surfLoad) *
  (sin (inxi impLoadAngle))) * (sin (inxi baseAngle)) -
  (inxi baseHydroForce)) * tan (inxi fricAngle) + (inxi cohesion) *
  (inxi baseWthX) * sec (inxi baseAngle)

eq8 = inxi shearRNoIntsl $=
  (((inxi slcWght) + (inxi surfHydroForce) * (cos (inxi surfAngle))) * (cos (inxi baseAngle)) +
  (- (inxi watrForceDif) +
  (inxi surfHydroForce) * sin (inxi surfAngle) + (inxi surfLoad) *
  (sin (inxi impLoadAngle))) * (sin (inxi baseAngle)) -
  (inxi baseHydroForce)) * tan (inxi fricAngle) + (inxi cohesion) *
  (inxi baseWthX) * sec (inxi baseAngle)

-------old chunk---------

resShrDerivation :: [Contents]
resShrDerivation = [

  foldlSP [S "The", phrase shrResI, S "of a slice is", 
  S "defined as", ch shrResI, S "in" +:+. makeRef2S genDef3Label, S "The",
  phrase nrmFSubWat, S "in the", phrase equation, S "for", ch shrResI,
  S "of the soil is defined in the perpendicular force equilibrium",
  S "of a slice from", makeRefS bsShrFEq `sC` S "using the", getTandS nrmFSubWat,
  S "of", makeRef2S effStress, S "shown in", eqN 5],
  
  eqUnR' $ (inxi nrmFSubWat) $= eqlExpr cos sin (\x y -> x -
  inxiM1 intShrForce + inxi intShrForce + y) - inxi baseHydroForce,
  
  foldlSP [plural value `ofThe'` S "interslice forces",
  ch intNormForce `sAnd` ch intShrForce, S "in the", phrase equation,
  S "are unknown, while the other", plural value,
  S "are found from the physical force", plural definition, S "of",
  makeRef2S sliceWght, S "to" +:+. makeRef2S lengthLs,
  S "Consider a force equilibrium without the affect of interslice forces" `sC`
  S "to obtain a solvable value as done for", ch nrmFNoIntsl, S "in", eqN 2],

  eqUnR' $
  (inxi nrmFNoIntsl) $= (((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle)) + (inxi surfLoad) * (cos (inxi impLoadAngle))) *
  (cos (inxi baseAngle)) + (negate (sy earthqkLoadFctr) * (inxi slcWght) -
  (inxi watrForce) + (inxiM1 watrForce) + (inxi surfHydroForce) *
  sin (inxi surfAngle) + (inxi surfLoad) * (sin (inxi impLoadAngle))) *
  (sin (inxi baseAngle)) - (inxi baseHydroForce)),
  
  foldlSP [S "Using", ch nrmFNoIntsl `sC` S "a", phrase shearRNoIntsl,
  shearRNoIntsl ^. defn, S "can be solved for in terms of all known",
  plural value, S "as done in", eqN 3],
  
  eqUnR' $
  inxi shearRNoIntsl $= (inxi nrmFNoIntsl) * tan (inxi fricAngle) +
  (inxi cohesion) * (inxi baseWthX) * sec (inxi baseAngle) $=
  (((inxi slcWght) + (inxi surfHydroForce) * (cos (inxi surfAngle)) +
  (inxi surfLoad) * (cos (inxi impLoadAngle))) * (cos (inxi baseAngle)) +
  (negate (sy earthqkLoadFctr) * (inxi slcWght) - (inxi watrForceDif) +
  (inxi surfHydroForce) * sin (inxi surfAngle) + (inxi surfLoad) *
  (sin (inxi impLoadAngle))) * (sin (inxi baseAngle)) -
  (inxi baseHydroForce)) * tan (inxi fricAngle) + (inxi cohesion) *
  (inxi baseWthX) * sec (inxi baseAngle)

  ]

------------------------------------------------------------------

mobShr_deriv_sentences_ssp_s1 :: [Sentence]
mobShr_deriv_sentences_ssp_s1 = [S "The", phrase mobShrI, S "acting on a slice is defined as",
  ch mobShrI, S "from the force equilibrium in", makeRef2S genDef2Label `sC`
  S "also shown in", eqN 5]

mobShr_deriv_sentences_ssp_s2 :: [Sentence]
mobShr_deriv_sentences_ssp_s2 = [S "The", phrase equation, S "is unsolvable, containing the unknown",
  getTandS intNormForce, S "and" +:+. getTandS intShrForce,
  S "Consider a force equilibrium", S wiif `sC` S "to obtain the",
  getTandS shearFNoIntsl `sC` S "as done in", eqN 6]

mobShr_deriv_sentences_ssp_s3 :: [Sentence]
mobShr_deriv_sentences_ssp_s3 = [S "The" +:+ plural value +:+ S "of" +:+ 
  ch shearFNoIntsl +:+ S "is now defined completely in terms of the" +:+
  S "known" +:+. plural value +:+ S "This can be further simplified by considering assumptions" +:+
  makeRef2S newA10 +:+ S "and" +:+ makeRef2S newA12 `sC`
  S "which state that the seismic coefficient and the external force" `sC` S "respectively"
  `sC` S "are0" +:+ S "Removing seismic and external forces yields " +:+ eqN 7]


mobShrDerivation_sentence :: [Sentence]
mobShrDerivation_sentence = map foldlSentCol [mobShr_deriv_sentences_ssp_s1, mobShr_deriv_sentences_ssp_s2,
  mobShr_deriv_sentences_ssp_s3]

mobShr_deriv_eqns_ssp :: [Expr]
mobShr_deriv_eqns_ssp = [eq4, eq5, eq6]

eq4, eq5, eq6:: Expr
eq4 = inxi mobShrI $= eqlExpr sin cos
    (\x y -> x - inxiM1 intShrForce + inxi intShrForce + y)

eq5 = inxi shearFNoIntsl $= ((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle)) + (inxi surfLoad) * (cos (inxi impLoadAngle))) *
  (sin (inxi baseAngle)) - (negate (sy earthqkLoadFctr) * (inxi slcWght) -
  (inxi watrForceDif) + (inxi surfHydroForce) * sin (inxi surfAngle) +
  (inxi surfLoad) * (sin (inxi impLoadAngle))) * (cos (inxi baseAngle))

eq6 = inxi shearFNoIntsl $= ((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle))) *
  (sin (inxi baseAngle)) -
  ((inxi watrForceDif) + (inxi surfHydroForce) * sin (inxi surfAngle)) * (cos (inxi baseAngle))

  ------old chunk-----
mobShrDerivation :: [Contents]
mobShrDerivation = [

  foldlSP [S "The", phrase mobShrI, S "acting on a slice is defined as",
  ch mobShrI, S "from the force equilibrium in", makeRef2S genDef2Label `sC`
  S "also shown in", eqN 4],
  
  eqUnR' $ inxi mobShrI $= eqlExpr sin cos
    (\x y -> x - inxiM1 intShrForce + inxi intShrForce + y),
  
  foldlSP [S "The", phrase equation, S "is unsolvable, containing the unknown",
  getTandS intNormForce, S "and" +:+. getTandS intShrForce,
  S "Consider a force equilibrium", S wiif `sC` S "to obtain the",
  getTandS shearFNoIntsl `sC` S "as done in", eqN 5],
  
  eqUnR' $
  inxi shearFNoIntsl $= ((inxi slcWght) + (inxi surfHydroForce) *
  (cos (inxi surfAngle)) + (inxi surfLoad) * (cos (inxi impLoadAngle))) *
  (sin (inxi baseAngle)) - (negate (sy earthqkLoadFctr) * (inxi slcWght) -
  (inxi watrForceDif) + (inxi surfHydroForce) * sin (inxi surfAngle) +
  (inxi surfLoad) * (sin (inxi impLoadAngle))) * (cos (inxi baseAngle)),
  
  foldlSP [S "The", plural value, S "of", ch shearRNoIntsl `sAnd`
  ch shearFNoIntsl, S "are now defined completely in terms of the",
  S "known force property", plural value, S "of", makeRef2S sliceWght, S "to", 
  makeRef2S lengthLs]

  ]-}
