module Main (main) where

-- import Language.Drasil.Code (Choices(..), CodeSpec, codeSpec, Comments(..), 
--   ConstraintBehaviour(..), ImplementationType(..), Lang(..), Logging(..), 
--   Structure(..))
import Language.Drasil.Generate (gen)
import Language.Drasil.Printers (DocType(SRS, Website), DocSpec(DocSpec))

import Drasil.SSP.Body (srs, printSetting) -- si

-- code :: CodeSpec
-- code = codeSpec si choices []

-- choices :: Choices
-- choices = Choices {
--   lang = [Python, Cpp, CSharp, Java],
--   impType = Program,
--   logFile = "log.txt",
--   logging = LogNone,         -- LogNone, LogFunc
--   comments = [],    -- CommentFunc, CommentClass, CommentMod
--   onSfwrConstraint = Warning,  -- Warning, Exception
--   onPhysConstraint = Warning,  -- Warning, Exception
--   inputStructure = Unbundled    -- Unbundled, Bundled
-- }
       
main :: IO ()            
main = do
  gen (DocSpec Website "SSP_SRS") srs printSetting
  gen (DocSpec SRS "SSP_SRS")     srs printSetting
  -- for when we can generate code again, uncomment this file
  --genCode choices code
