module Data.Drasil.Citations (
  koothoor2013, parnas1986, smithLai2005,
  journalCGJ
  ) where

import Language.Drasil --(S,(:+:),(+:+),sC,phrase,F,Accent(..),Citation(..),CiteField(..))
import Data.Drasil.People (spencerSmith, dParnas, nKoothoor, lLai,
  pjAgerfalk, nKraiem, jRalyte, pcClements)
import Data.Drasil.Software.Products (sciCompS)

---------------
-- CITATIONS --
---------------

koothoor2013, parnas1986, smithLai2005 :: Citation

koothoor2013 = 
  cMThesis "koothoor2013" [nKoothoor] 
  (S "A document drive approach to certifying" +:+ phrase sciCompS)
  (S "McMaster University") 2013 [address (S "Hamilton, ON, Canada")]
  
parnas1986 = cArticle "parnas1986" [dParnas, pcClements] 
  (S "A rational design process: How and why to fake it")
  (S "IEEE Transactions on Software Engineering") 1986
  [month Feb, volume 12, number 2, pages [251,257], address (S "Washington, USA")]

smithLai2005 = cInProceedings "smithLai2005" [spencerSmith, lLai]
  (S "A new requirements template for scientific computing")
  (S "Proceedings of the First International Workshop on" +:+
  S "Situational Requirements Engineering Processes - Methods," +:+
  S "Techniques and Tools to Support Situation-Specific Requirements" +:+
  S "Engineering Processes, SREP'05") 2005
  [ editor [pjAgerfalk, nKraiem, jRalyte], address (S "Paris, France")
  , pages [107,121], 
  note (S "In conjunction with 13th IEEE International Requirements" +:+
  S "Engineering Conference,")] 

------------------------
-- COMMON CITE-FIELDS --
------------------------

jnlCGJ :: CiteField
jnlCGJ = journal $ S "Canadian Geotechnical Journal"

journalCGJ :: Int -> Int -> [CiteField]
journalCGJ vol issue = [jnlCGJ, volume vol, number issue]