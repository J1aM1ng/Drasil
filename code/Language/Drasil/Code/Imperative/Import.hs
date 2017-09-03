module Language.Drasil.Code.Imperative.Import(generator, generateCode) where

import Language.Drasil.Code.Code as C
import Language.Drasil.Code.Imperative.AST as I hiding ((&=),assign,State,return)
import qualified Language.Drasil.Code.Imperative.AST as I (assign,return)
import Language.Drasil.Code.Imperative.LanguageRenderer (Options(..))
import Language.Drasil.Code.Imperative.Parsers.ConfigParser (pythonLabel, cppLabel, cSharpLabel, javaLabel)
import Language.Drasil.Code.CodeGeneration (createCodeFiles, makeCode)
import Language.Drasil.Chunk.Code
import Language.Drasil.Expr as E hiding (State)
import Language.Drasil.Expr.Extract hiding (vars)
import Language.Drasil.CodeSpec hiding (codeSpec, Mod(..))
import qualified Language.Drasil.CodeSpec as CS (Mod(..))
import Language.Drasil.DataDesc

import Prelude hiding (log, exp, const)
import Data.List (intersperse, (\\), stripPrefix)
import System.Directory
import Data.Map (member)
import qualified Data.Map as Map (lookup)
import Data.Maybe (maybe)
import Language.Drasil.ChunkDB (symbLookup, HasSymbolTable(..))
import Control.Lens ((^.))
import Control.Monad (when)
import Control.Monad.Reader (Reader, ask, runReader, withReader)

-- Private State, used to push these options around the generator
data State = State {
  codeSpec :: CodeSpec,
  inStruct :: Structure,
  logName :: String,
  logKind :: Logging,
  commented :: Comments,
  currentModule :: String,

  sfwrCBody :: Expr -> Body,
  physCBody :: Expr -> Body
}

-- function to choose how to deal with
-- 1. constraints
-- 2. how to structure the input "module"
-- 3. logging assignments
chooseConstr :: ConstraintBehaviour -> Expr -> Body
chooseConstr Warning   = constrWarn
chooseConstr Exception = constrExc

chooseInStructure :: Structure -> Reader State [Module]
chooseInStructure Loose   = genInputModNoClass
chooseInStructure AsClass = genInputModClass

chooseLogging :: Logging -> (Value -> Value -> Reader State Statement)
chooseLogging LogVar = loggedAssign
chooseLogging LogAll = loggedAssign
chooseLogging _      = (\x y -> return $ I.assign x y)

generator :: Choices -> CodeSpec -> State
generator chs spec = State {
  -- constants
  codeSpec = spec,
  inStruct = inputStructure chs,
  logKind  = logging chs,
  commented = comments chs,
  -- state
  currentModule = "",

  -- next depend on chs
  logName = logFile chs,
  sfwrCBody = chooseConstr $ onSfwrConstraint chs,
  physCBody = chooseConstr $ onPhysConstraint chs
}

assign :: Value -> Value -> Reader State Statement
assign x y = do
  g <- ask
  chooseLogging (logKind g) x y

publicMethod :: MethodType -> Label -> [Parameter] -> Reader State Body -> Reader State Method
publicMethod mt l pl u = do
  g <- ask
  genMethodCall Public Static (commented g) (logKind g) mt l pl u

generateCode :: Choices -> State -> IO ()
generateCode ch g =
  do workingDir <- getCurrentDirectory
     mapM_ (\x -> do
          createDirectoryIfMissing False (getDir x)
          setCurrentDirectory (getDir x)
          when (x == Java) $ createDirectoryIfMissing False prog
          when (x == Java) $ setCurrentDirectory prog
          createCodeFiles $ makeCode
            (getLabel x)
            (Options Nothing Nothing Nothing (Just "Code"))
            (toAbsCode prog modules)
          setCurrentDirectory workingDir) (lang $ ch)
  where prog = codeName $ program $ codeSpec g
        modules = runReader genModules g

genModules :: Reader State [Module]
genModules = do
  g <- ask
  let s = codeSpec g
  mn     <- genMain
  inp    <- chooseInStructure $ inStruct g
  out    <- genOutputMod $ outputs s
  moddef <- sequence $ fmap genModDef (mods s) -- hack ?
  return $ (mn : inp ++ out ++ moddef)

-- private utilities used in generateCode
getLabel, getDir :: Lang -> String
getLabel Cpp = cppLabel
getLabel CSharp = cSharpLabel
getLabel Java = javaLabel
getLabel Python = pythonLabel
getDir Cpp = "cpp"
getDir CSharp = "csharp"
getDir Java = "java"
getDir Python = "python"

liftS :: Reader a b -> Reader a [b]
liftS = fmap (\x -> [x])

------- INPUT ----------

genInputModClass :: Reader State [Module]
genInputModClass =
  sequence $ [ genModule "InputParameters" Nothing (Just $ liftS genInputClass),
               genModule "DerivedValues" (Just $ liftS genInputDerived) Nothing,
               genModule "InputConstraints" (Just $ liftS genInputConstraints) Nothing
             ]

genInputModNoClass :: Reader State [Module]
genInputModNoClass = do
  g <- ask
  let ins = inputs $ codeSpec g
  inpDer    <- genInputDerived
  inpConstr <- genInputConstraints
  return $ [ buildModule "InputParameters" []
             (map (\x -> VarDecDef (codeName x) (convType $ codeType x) (defaultValue' $ convType $ codeType x)) ins)
             [inpDer , inpConstr]
             []
           ]

genInputClass :: Reader State Class
genInputClass = do
  g <- ask
  let ins          = inputs $ codeSpec g
      inputVars    =
          map (\x -> pubMVar 0 (convType $ codeType x) (codeName x)) ins
      vars         = map svToVar inputVars
      vals         = map (defaultValue' . convType . codeType) ins
  return $ pubClass
    "InputParameters"
    Nothing
    inputVars
    (
      [ constructor
          "InputParameters"
          []
          [zipBlockWith (\x y -> runReader (assign x y) g) vars vals]--,
      ]
    )

genInputConstraints :: Reader State Method
genInputConstraints = do
  g <- ask
  let vars   = inputs $ codeSpec g
      cm     = cMap $ codeSpec g
      sfwrCs = concatMap (\x -> sfwrLookup x cm) vars
      physCs = concatMap (\x -> physLookup x cm) vars
  parms <- getParams vars
  publicMethod methodTypeVoid "input_constraints" parms
      (return $ [ block $
        (map (\x -> ifCond [((?!) (convExpr g x), sfwrCBody g x)] noElse) sfwrCs) ++
        (map (\x -> ifCond [((?!) (convExpr g x), physCBody g x)] noElse) physCs)
      ])

genInputDerived :: Reader State Method
genInputDerived = do
  g <- ask
  let dvals = derivedInputs $ codeSpec g
  parms <- getParams $ map codevar dvals
  publicMethod methodTypeVoid "derived_values" parms
      (return $ concatMap (\x -> runReader (genCalcBlock CalcAssign (codeName x) (codeEquat x)) g) dvals)

-- need Expr -> String to print constraint
constrWarn :: Expr -> Body
constrWarn _ = oneLiner $ printStrLn "Warning: constraint violated"

constrExc :: Expr -> Body
constrExc _ = oneLiner $ throw "InputError"

---- CONST ----

{-
genConstMod :: Reader State Module
genConstMod = buildModule "Constants" []
  (map (\x -> VarDecDef (codeName x) (convType $ codeType x) (convExpr g $ codeEquat x)) (const $ codeSpec g))
  [] [{- genConstClassD g -}]

genConstClassD :: Reader State Class
genConstClassD = pubClass "Constants" Nothing genVars []
  where genVars = map (\x -> pubGVar 0 (convType $ codeType x) (codeName x)) (const $ codeSpec g)
-}

------- CALC ----------
{-
genCalcMod :: String -> [CodeDefinition] -> Reader State Module
genCalcMod n defs = buildModule n [] [] (map genCalcFunc (filter (validExpr . codeEquat) defs)) []
-}
genCalcFunc :: CodeDefinition -> Reader State Method
genCalcFunc cdef = do
  g <- ask
  parms <- getParams (codevars' (codeEquat cdef) $ sysinfodb $ codeSpec g)
  publicMethod
    (methodType $ convType (codeType cdef))
    (codeName cdef)
    parms
    (genCalcBlock CalcReturn (codeName cdef) (codeEquat cdef))

data CalcType = CalcAssign | CalcReturn deriving Eq

genCalcBlock :: CalcType -> String -> Expr -> Reader State Body
genCalcBlock t' v' e' = do
  g <- ask
  doit g t' v' e'
    where
    doit :: State -> CalcType -> String -> Expr -> Reader State Body
    doit g t v e
      | containsCase e   = genCaseBlock t v $ getCases e
      | t == CalcAssign  = fmap oneLiner $ do { vv <- variable v ; assign vv (convExpr g e)}
      | otherwise        = return $ oneLiner $ I.return $ convExpr g e

genCaseBlock :: CalcType -> String -> [(Expr,Relation)] -> Reader State Body
genCaseBlock t v cs = do
  g <- ask
  let genIf = map (\(e,r) -> (convExpr g r, runReader (genCalcBlock t v e) g))
  return $ oneLiner $ ifCond (genIf cs) noElse

----- OUTPUT -------

genOutputMod :: [CodeChunk] -> Reader State [Module]
genOutputMod outs = liftS $ genModule "OutputFormat" (Just $ liftS $ genOutputFormat outs) Nothing

genOutputFormat :: [CodeChunk] -> Reader State Method
genOutputFormat outs =
  let l_outfile = "outfile"
      v_outfile = var l_outfile
  in do
    g <- ask
    parms <- getParams outs
    publicMethod methodTypeVoid "write_output" parms (return [ block $ [
      varDec l_outfile outfile,
      openFileW v_outfile (litString "output.txt") ] ++
      concatMap
        (\x -> [ printFileStr v_outfile ((codeName x) ++ " = "),
                 printFileLn v_outfile (convType $ codeType x) (runReader (variable $ codeName x) g)
               ] ) outs ++ [
      closeFile v_outfile ] ])

-----

genMethodCall :: Scope -> Permanence -> Comments -> Logging -> MethodType -> Label -> [Parameter]
                  -> Reader State Body -> Reader State Method
genMethodCall s pr doComments doLog t n p b = do
  let loggedBody LogFunc = loggedMethod n p b
      loggedBody LogAll  = loggedMethod n p b
      loggedBody _       = b
      commBody CommentFunc = commMethod n p
      commBody _           = id
  bod <- commBody doComments (loggedBody doLog)
  return $ Method n s pr t p bod

commMethod :: Label -> [Parameter] -> Reader State Body -> Reader State Body
commMethod n p b = do
  g <- ask
  rest <- b
  return $ (
    block [
      comment $ "function '" ++ n ++ "': " ++ (funcTerm n (fMap $ codeSpec g)),
      multi $ map
        (\x -> comment $ "parameter '" ++ (paramName x) ++ "': " ++ (varTerm (paramName x) (vMap $ codeSpec g))) p
    ]) : rest 

loggedMethod :: Label -> [Parameter] -> Reader State Body -> Reader State Body
loggedMethod n p b =
  let l_outfile = "outfile"
      v_outfile = var l_outfile
  in do
    g <- ask
    rest <- b
    return $ ( block [
      varDec l_outfile outfile,
      openFileW v_outfile (litString $ logName g),
      printFileStr v_outfile ("function " ++ n ++ "("),
      printParams p v_outfile,
      printFileStrLn v_outfile ") called",
      closeFile v_outfile ] )
      : rest
  where
    printParams ps v_outfile = multi $
      intersperse (printFileStr v_outfile ", ") $
      map (\x -> printFile v_outfile (paramType x) (paramVal x)) ps

---- MAIN ---

genModule :: Name
               -> Maybe (Reader State [FunctionDecl])
               -> Maybe (Reader State [Class])
               -> Reader State Module
genModule n maybeMs maybeCs = do
  g <- ask
  let ls = maybe [] id (Map.lookup n (dMap $ codeSpec g))
      updateState = withReader (\s -> s { currentModule = n })
  cs <- maybe (return []) updateState maybeCs
  ms <- maybe (return []) updateState maybeMs
  return $ buildModule n ls [] ms cs


genMain :: Reader State Module
genMain = genModule "Control" (Just $ liftS $ genMainFunc) Nothing

genMainFunc :: Reader State FunctionDecl
genMainFunc =
  let l_filename = "inputfile"
      v_filename = var l_filename
      l_params = "inParams"
      v_params = var l_params
  in do
    g <- ask
    let args1 x = getArgs $ codevars' (codeEquat x) $ sysinfodb $ codeSpec g
    args2 <- getArgs $ outputs $ codeSpec g
    return $ mainMethod $ body $ [
      varDecDef l_filename string $ arg 0 ,
      objDecNewVoid l_params "InputParameters" (obj "InputParameters") ,
      valStmt $ fApp g (funcPrefix ++ "get_input") [v_filename, v_params] ,
      valStmt $ fApp g "derived_values" [v_params] ,
      valStmt $ fApp g "input_constraints" [v_params]
      ] ++ map (\x -> varDecDef (nopfx $ codeName x) (convType $ codeType x)
                    (fApp g (codeName x) (runReader (args1 x) g)))
          (execOrder $ codeSpec g)
      ++ [ valStmt $ fApp g "write_output" args2 ]


-----

loggedAssign :: Value -> Value -> Reader State Statement
loggedAssign a b =
  let l_outfile = "outfile"
      v_outfile = var l_outfile
  in do
    g <- ask
    return $ multi [
      I.assign a b,
      varDec l_outfile outfile,
      openFileW v_outfile (litString $ logName g),
      printFileStr v_outfile ("var '" ++ (valName a) ++ "' assigned to "),
      printFile v_outfile (convType $ varType (valName b) (vMap $ codeSpec g)) b,
      printFileStrLn v_outfile (" in module " ++ currentModule g),
      closeFile v_outfile ]

-- helpers

nopfx :: String -> String
nopfx s = maybe s id (stripPrefix funcPrefix s)

variable :: String -> Reader State Value
variable s' = do
  g <- ask
  return $ doit g s'
    where
    doit :: State -> String -> Value
    doit g s | member s (constMap $ codeSpec g) =
      maybe (error "impossible") (convExpr g . codeEquat) (Map.lookup s (constMap $ codeSpec g)) --extvar "Constants" s
             | s `elem` (map codeName $ inputs $ codeSpec g) = (var "inParams")$->(var s)
             | otherwise                        = var s
  
fApp :: State -> String -> ([Value] -> Value)
fApp g s
  | member s (eMap $ codeSpec g) =
      maybe (error "impossible")
        (\x -> if x /= currentModule g then funcApp x s else funcApp' s)
        (Map.lookup s (eMap $ codeSpec g))
  | otherwise = funcApp' s

getParams :: [CodeChunk] -> Reader State [Parameter]
getParams cs = do
  g <- ask
  let ins = inputs $ codeSpec g
      csSubIns = cs \\ ins
      ps = map (\y -> param (codeName y) (convType $ codeType y))
            (filter (\x -> not $ member (codeName x) (constMap $ codeSpec g)) csSubIns)
  return $ if length csSubIns < length cs
           then (param "inParams" (obj "InputParameters")):ps  -- todo:  make general
           else ps

getArgs :: [CodeChunk] -> Reader State [Value]
getArgs cs = do
  g <- ask
  let ins = inputs $ codeSpec g
      csSubIns = cs \\ ins
      args = map (var . codeName)
            (filter (\x -> not $ member (codeName x) (constMap $ codeSpec g)) csSubIns)
  return $ if length csSubIns < length cs
           then (var "inParams"):args  -- todo:  make general
           else args

paramType :: Parameter -> StateType
paramType (StateParam _ s) = s
paramType (FuncParam _ _ _) = error "Function param not implemented"

paramVal :: Parameter -> Value
paramVal (StateParam l _) = var l
paramVal (FuncParam _ _ _) = error "Function param not implemented"

paramName :: Parameter -> String
paramName (StateParam l _) = l
paramName (FuncParam _ _ _) = error "Function param not implemented"

valName :: Value -> String
valName (Lit (LitBool b)) = show b
valName (Lit (LitInt i)) = show i
valName (Lit (LitFloat f)) = show f
valName (Lit (LitChar c)) = [c]
valName (Lit (LitStr s)) = s
valName (Var _ n) = n
valName (ObjVar o v) = valName o ++ "." ++ valName v
valName (ObjAccess o (ListAccess v)) = valName o ++ "[" ++ valName v ++ "]"
valName _ = error "Value has no name"

convType :: C.CodeType -> I.StateType
convType C.Boolean = bool
convType C.Integer = int
convType C.Float = float
convType C.Char = char
convType C.String = string
convType (C.List t) = listT $ convType t
convType (C.Object n) = obj n
convType _ = error "No type conversion"

{-
-- Some Expr can't be converted to code yet...
-- rather than stop execution with failure,
-- just check ahead of time and don't try to convert for now
validExpr :: Expr -> Bool
validExpr (V _)        = True
validExpr (Dbl _)      = True
validExpr (Int _)      = True
validExpr (Bln _)      = True
validExpr (a :/ b)     = (validExpr a) && (validExpr b)
validExpr (a :* b)     = (validExpr a) && (validExpr b)
validExpr (a :+ b)     = (validExpr a) && (validExpr b)
validExpr (a :^ b)     = (validExpr a) && (validExpr b)
validExpr (a :- b)     = (validExpr a) && (validExpr b)
validExpr (a :. b)     = (validExpr a) && (validExpr b)
validExpr (a :&& b)    = (validExpr a) && (validExpr b)
validExpr (a :|| b)    = (validExpr a) && (validExpr b)
validExpr (Deriv _ _ _) = False
validExpr (E.Not e)      = validExpr e
validExpr (Neg e)      = validExpr e
validExpr (C _)        = True
validExpr (FCall (C _) x)  = foldl (&&) True (map validExpr x)
validExpr (FCall _ _)  = False
validExpr (a := b)     = (validExpr a) && (validExpr b)
validExpr (a :!= b)    = (validExpr a) && (validExpr b)
validExpr (a :> b)     = (validExpr a) && (validExpr b)
validExpr (a :< b)     = (validExpr a) && (validExpr b)
validExpr (a :<= b)    = (validExpr a) && (validExpr b)
validExpr (a :>= b)    = (validExpr a) && (validExpr b)
validExpr (UnaryOp u)  = validunop u
validExpr (Grouping e) = validExpr e
validExpr (BinaryOp _) = False
validExpr (Case c)     = foldl (&&) True (map (\(e, r) -> validExpr e && validExpr r) c)
validExpr _            = False

validunop :: UFunc -> Bool
validunop (E.Sqrt e)         = validExpr e
validunop (E.Log e)          = validExpr e
validunop (E.Abs e)          = validExpr e
validunop (E.Exp e)          = validExpr e
validunop (E.Sin e)          = validExpr e
validunop (E.Cos e)          = validExpr e
validunop (E.Tan e)          = validExpr e
validunop (E.Csc e)          = validExpr e
validunop (E.Sec e)          = validExpr e
validunop (E.Cot e)          = validExpr e
validunop _                  = False
-}

convExpr :: State -> Expr -> Value
convExpr _ (V v)        = litString v  -- V constructor should be removed
convExpr _ (Dbl d)      = litFloat d
convExpr _ (Int i)      = litInt i
convExpr _ (Bln b)      = litBool b
convExpr _ ((Int a) :/ (Int b)) = (litFloat $ fromIntegral a) #/ (litFloat $ fromIntegral b) -- hack to deal with integer division
convExpr g (a :/ b)     = (convExpr g a) #/ (convExpr g b)
convExpr g (a :* b)     = (convExpr g a) #* (convExpr g b)
convExpr g (a :+ b)     = (convExpr g a) #+ (convExpr g b)
convExpr g (a :^ b)     = (convExpr g a) #^ (convExpr g b)
convExpr g (0 :- b)     = (convExpr g (Neg b))
convExpr g (a :- b)     = (convExpr g a) #- (convExpr g b)
convExpr g (a :. b)     = (convExpr g a) #* (convExpr g b)
convExpr g (a :&& b)    = (convExpr g a) ?&& (convExpr g b)
convExpr g (a :|| b)    = (convExpr g a) ?|| (convExpr g b)
convExpr _ (Deriv _ _ _) = litString "**convExpr :: Deriv unimplemented**"
convExpr g (E.Not e)      = (?!) (convExpr g e)
convExpr g (Neg e)      = (#~) (convExpr g e)
convExpr g (C c)        = runReader (variable $ codeName $ codevar $ symbLookup c $ (sysinfodb $ codeSpec g) ^. symbolTable) g
convExpr g (Index a i)  = (convExpr g a)$.(listAccess $ convExpr g i)
convExpr g (Len a)      = (convExpr g a)$.listSize
convExpr g (Append a v) = (convExpr g a)$.(listAppend $ convExpr g v)
convExpr g (FCall (C c) x)  = fApp g (codeName (codefunc $ symbLookup c $ (sysinfodb $ codeSpec g) ^. symbolTable)) (map (convExpr g) x)
convExpr _ (FCall _ _)  = litString "**convExpr :: BinaryOp unimplemented**"
convExpr g (a := b)     = (convExpr g a) ?== (convExpr g b)
convExpr g (a :!= b)    = (convExpr g a) ?!= (convExpr g b)
convExpr g (a :> b)     = (convExpr g a) ?> (convExpr g b)
convExpr g (a :< b)     = (convExpr g a) ?< (convExpr g b)
convExpr g (a :<= b)    = (convExpr g a) ?<= (convExpr g b)
convExpr g (a :>= b)    = (convExpr g a) ?>= (convExpr g b)
convExpr g (UnaryOp u)  = runReader (unop u) g
convExpr g (Grouping e) = convExpr g e
convExpr _ (BinaryOp _) = litString "**convExpr :: BinaryOp unimplemented**"
convExpr _ (Case _)     = error "**convExpr :: Case should be dealt with separately**"
convExpr _ _           = litString "**convExpr :: ? unimplemented**"

unop :: UFunc -> Reader State Value
unop (E.Sqrt e)         = ask >>= \g -> return $ (#/^) (convExpr g e)
unop (E.Log e)          = ask >>= \g -> return $ I.log (convExpr g e)
unop (E.Abs e)          = ask >>= \g -> return $ (#|) (convExpr g e)
unop (E.Exp e)          = ask >>= \g -> return $ I.exp (convExpr g e)
unop (E.Sin e)          = ask >>= \g -> return $ I.sin (convExpr g e)
unop (E.Cos e)          = ask >>= \g -> return $ I.cos (convExpr g e)
unop (E.Tan e)          = ask >>= \g -> return $ I.tan (convExpr g e)
unop (E.Csc e)          = ask >>= \g -> return $ I.csc (convExpr g e)
unop (E.Sec e)          = ask >>= \g -> return $ I.sec (convExpr g e)
unop (E.Cot e)          = ask >>= \g -> return $ I.cot (convExpr g e)
unop _                  = error "not implemented"


containsCase :: Expr -> Bool
containsCase (Case _) = True
containsCase (a :/ b)     = (containsCase a) || (containsCase b)
containsCase (a :* b)     = (containsCase a) || (containsCase b)
containsCase (a :+ b)     = (containsCase a) || (containsCase b)
containsCase (a :^ b)     = (containsCase a) || (containsCase b)
containsCase (a :- b)     = (containsCase a) || (containsCase b)
containsCase (a :. b)     = (containsCase a) || (containsCase b)
containsCase (a :&& b)    = (containsCase a) || (containsCase b)
containsCase (a :|| b)    = (containsCase a) || (containsCase b)
containsCase (Deriv _ _ _) = error "not implemented"
containsCase (E.Not e)      = containsCase e
containsCase (Neg e)      = containsCase e
containsCase (a := b)     = (containsCase a) || (containsCase b)
containsCase (a :!= b)    = (containsCase a) || (containsCase b)
containsCase (a :> b)     = (containsCase a) || (containsCase b)
containsCase (a :< b)     = (containsCase a) || (containsCase b)
containsCase (a :<= b)    = (containsCase a) || (containsCase b)
containsCase (a :>= b)    = (containsCase a) || (containsCase b)
containsCase (UnaryOp u)  = unopcase u
containsCase (Grouping e) = containsCase e
containsCase (BinaryOp _) = error "not implemented"
containsCase _            = False

unopcase :: UFunc -> Bool
unopcase (E.Sqrt e)         = containsCase e
unopcase (E.Log e)          = containsCase e
unopcase (E.Abs e)          = containsCase e
unopcase (E.Exp e)          = containsCase e
unopcase (E.Sin e)          = containsCase e
unopcase (E.Cos e)          = containsCase e
unopcase (E.Tan e)          = containsCase e
unopcase (E.Sec e)          = containsCase e
unopcase (E.Csc e)          = containsCase e
unopcase (E.Cot e)          = containsCase e
unopcase _                  = error "not implemented"

getCases :: Expr -> [(Expr, Relation)]
getCases (Case a)     = a
getCases e            = getCases (compactCase e)

compactCase :: Expr -> Expr
compactCase (a :/ b)     = compactCaseBinary (:/) a b
compactCase (a :* b)     = compactCaseBinary (:*) a b
compactCase (a :+ b)     = compactCaseBinary (:+) a b
compactCase (a :^ b)     = compactCaseBinary (:^) a b
compactCase (a :- b)     = compactCaseBinary (:-) a b
compactCase (a :. b)     = compactCaseBinary (:.) a b
compactCase (a :&& b)    = compactCaseBinary (:&&) a b
compactCase (a :|| b)    = compactCaseBinary (:||) a b
compactCase (Deriv _ _ _) = error "not implemented"
compactCase (E.Not e)    = compactCaseUnary E.Not e
compactCase (Neg e)      = compactCaseUnary Neg e
compactCase (a := b)     = compactCaseBinary (:=) a b
compactCase (a :!= b)    = compactCaseBinary (:!=) a b
compactCase (a :> b)     = compactCaseBinary (:>) a b
compactCase (a :< b)     = compactCaseBinary (:<) a b
compactCase (a :<= b)    = compactCaseBinary (:<=) a b
compactCase (a :>= b)    = compactCaseBinary (:>=) a b
compactCase (UnaryOp u)  = unopcomcase u
compactCase (Grouping e) = compactCaseUnary Grouping e
compactCase (BinaryOp _) = error "not implemented"
compactCase e            = e

unopcomcase :: UFunc -> Expr
unopcomcase (E.Sqrt e)  = compactCaseUnary (UnaryOp . E.Sqrt) e
unopcomcase (E.Log e)   = compactCaseUnary (UnaryOp . E.Log) e
unopcomcase (E.Abs e)   = compactCaseUnary (UnaryOp . E.Abs) e
unopcomcase (E.Exp e)   = compactCaseUnary (UnaryOp . E.Exp) e
unopcomcase (E.Sin e)   = compactCaseUnary (UnaryOp . E.Sin) e
unopcomcase (E.Cos e)   = compactCaseUnary (UnaryOp . E.Cos) e
unopcomcase (E.Tan e)   = compactCaseUnary (UnaryOp . E.Tan) e
unopcomcase (E.Sec e)   = compactCaseUnary (UnaryOp . E.Sec) e
unopcomcase (E.Csc e)   = compactCaseUnary (UnaryOp . E.Csc) e
unopcomcase (E.Cot e)   = compactCaseUnary (UnaryOp . E.Cot) e
unopcomcase _           = error "not implemented"

compactCaseBinary :: (Expr -> Expr -> Expr) -> Expr -> Expr -> Expr
compactCaseBinary op (Case c) b = Case (map (\(e, r) -> (e `op` b, r)) c)
compactCaseBinary op a (Case c) = Case (map (\(e, r) -> (a `op` e, r)) c)
compactCaseBinary op a b        = (compactCase a) `op` (compactCase b)

compactCaseUnary :: (Expr -> Expr) -> Expr -> Expr
compactCaseUnary op (Case c) = Case (map (\(e, r) -> (op e, r)) c)
compactCaseUnary op a        = op (compactCase a)

-- medium hacks --
genModDef :: CS.Mod -> Reader State Module
genModDef (CS.Mod n fs) = genModule n (Just $ sequence $ map genFunc fs) Nothing

genFunc :: Func -> Reader State Method
genFunc (FDef (FuncDef n i o s)) = do
  g <- ask
  parms <- getParams i
  stmts <- mapM convStmt s
  publicMethod (methodType $ convType o) n parms
    (return [ block $
        (map (\x -> varDec (codeName x) (convType $ codeType x))
          (((fstdecl $ sysinfodb $ codeSpec g) s) \\ i))
        ++ stmts
    ])
genFunc (FData (FuncData n dd)) = genDataFunc n dd
genFunc (FCD cd) = genCalcFunc cd

convStmt :: FuncStmt -> Reader State Statement
convStmt (FAsg v e) = do
  g <- ask
  assign (var $ codeName v) (convExpr g e)
convStmt (FFor v e st) = do
  g <- ask
  stmts <- mapM convStmt st
  return $ for (varDecDef (codeName v) int (litInt 0)) (convExpr g e) ((&++) (var (codeName v)))
               [ block stmts ]
convStmt (FWhile e st) = do
  g <- ask 
  stmts <- mapM convStmt st
  return $ while (convExpr g e) [ block stmts ]
convStmt (FCond e tSt []) = do
  g <- ask
  stmts <- mapM convStmt tSt
  return $ ifCond [(convExpr g e, [ block stmts ])] noElse
convStmt (FCond e tSt eSt) = do
  g <- ask
  stmt1 <- mapM convStmt tSt
  stmt2 <- mapM convStmt eSt
  return $ ifCond [(convExpr g e, [ block stmt1 ])] [ block stmt2 ]
convStmt (FRet e) = ask >>= \g -> return $ I.return $ convExpr g e
convStmt (FThrow s) = return $ throw s
convStmt (FTry t c) = do
  stmt1 <- mapM convStmt t
  stmt2 <- mapM convStmt c
  return $ tryCatch [ block stmt1 ] [ block stmt2 ]
convStmt (FContinue) = return continue
convStmt (FVal e) = ask >>= \g -> return $ valStmt $ convExpr g e
convStmt (FDec v (C.List t)) = return $ listDec' (codeName v) (convType t) 0
convStmt (FDec v t) = return $ varDec (codeName v) (convType t)

-- this is really ugly!!
genDataFunc :: Name -> DataDesc -> Reader State Method
genDataFunc name dd = do
    g <- ask
    parms <- getParams $ getInputs dd
    publicMethod methodTypeVoid name (p_filename : parms) $
      return $ body $ [
      varDec l_infile infile,
      varDec l_line string,
      listDec' l_lines string 0,
      listDec' l_linetokens string 0,
      openFileR v_infile v_filename ] ++
      (concatMap (inData g) dd) ++ [
      closeFile v_infile ]
  where inData :: State -> Data -> [Statement]
        inData g (Singleton v) = [getFileInput v_infile (convType $ codeType v) (runReader (variable $ codeName v) g)]
        inData _ JunkData = [discardFileLine v_infile]
        inData g (Line lp d) =
          [ getFileInputLine v_infile v_line,
            stringSplit v_linetokens v_line d
          ] ++ lineData g lp (litInt 0)
        inData g (Lines lp Nothing d) =
          [ getFileInputAll v_infile v_lines,
            for (varDecDef l_i int (litInt 0)) (v_i ?< v_lines$.listSize) ((&++) v_i)
              ( body
                ( [ stringSplit v_linetokens (v_lines$.(listAccess v_i)) d
                  ] ++ lineData g lp v_i
                )
              )
          ]
        inData g (Lines lp (Just numLines) d) =
          [ for (varDecDef l_i int (litInt 0)) (v_i ?< (litInt numLines)) ((&++) v_i)
              ( body
                ( [ getFileInputLine v_infile v_line,
                    stringSplit v_linetokens v_line d
                  ] ++ lineData g lp v_i
                )
              )
          ]
        ---------------
        lineData :: State -> LinePattern -> Value -> [Statement]
        lineData g (Straight p) lineNo = patternData g p lineNo (litInt 0)
        lineData g (Repeat p Nothing) lineNo =
          [ for (varDecDef l_j int (litInt 0)) (v_j ?< (v_linetokens$.listSize #/ (litInt $ toInteger $ length p))$.(cast int float)) ((&++) v_j)
              ( body (patternData g p lineNo v_j) )
          ]
        lineData g (Repeat p (Just numPat)) lineNo =
          [ for (varDecDef l_j int (litInt 0)) (v_j ?< (litInt numPat)) ((&++) v_j)
              ( body (patternData g p lineNo v_j) )
          ]
        ---------------
        patternData :: State -> [Entry] -> Value -> Value -> [Statement]
        patternData g d lineNo patNo =
          let l = toInteger $ length d
          in  concatMap (\(x,y) -> runReader (entryData x lineNo patNo y) g) $ zip (map (\z -> (patNo #* (litInt l)) #+ (litInt z)) [0..l-1]) d
        ---------------
        entryData :: Value -> Value -> Value -> Entry -> Reader State [Statement]
        entryData tokIndex _ _ (Entry v) = do
          vv <- variable $ codeName v
          a <- assign vv $ (v_linetokens$.(listAccess tokIndex))$. (cast (convType $ codeType v) string)
          return [a]
        entryData tokIndex lineNo patNo (ListEntry indx v) = do
          vv <- variable $ codeName v
          a <- assign (indexData indx lineNo patNo vv) $
                (v_linetokens$.(listAccess tokIndex))$.(cast (listType (codeType v) (toInteger $ length indx)) string)
          return $ checkIndex indx lineNo patNo vv (codeType v) ++ [ a ]
        entryData _ _ _ JunkEntry = return []
        ---------------
        indexData :: [Ind] -> Value -> Value -> Value -> Value
        indexData [] _ _ v = v
        indexData ((Explicit i):is) l p v = indexData is l p (ObjAccess v (listAccess $ litInt i))
        indexData (WithLine:is) l p v = indexData is l p (ObjAccess v (listAccess l))
        indexData (WithPattern:is) l p v = indexData is l p (ObjAccess v (listAccess p))
        ---------------
        checkIndex :: [Ind] -> Value -> Value -> Value -> C.CodeType -> [Statement]
        checkIndex indx l p v s = checkIndex' indx len l p v (listBase s)
          where len = toInteger $ length indx
        checkIndex' [] _ _ _ _ _ = []
        checkIndex' ((Explicit i):is) n l p v s =
          [ while (v$.listSize ?<= (litInt i)) ( body [ valStmt $ v$.(listExtend $ listType' s n) ] ) ]
          ++ checkIndex' is (n-1) l p (v$.(listAccess $ litInt i)) s
        checkIndex' ((WithLine):is) n l p v s =
          [ while (v$.listSize ?<= l) ( body [ valStmt $ v$.(listExtend $ listType' s n ) ] ) ]
          ++ checkIndex' is (n-1) l p (v$.(listAccess l)) s
        checkIndex' ((WithPattern):is) n l p v s =
          [ while (v$.listSize ?<= p) ( body [ valStmt $ v$.(listExtend $ listType' s n ) ] ) ]
          ++ checkIndex' is (n-1) l p (v$.(listAccess p)) s
        ---------------
        listType :: C.CodeType -> Integer -> I.StateType
        listType _ 0 = error "No index given"
        listType (C.List t) 1 = convType t
        listType (C.List t) n = listType t (n-1)
        listType _ _ = error "Not a list type"
        ---------------
        listBase :: C.CodeType -> C.CodeType
        listBase (C.List t) = listBase t
        listBase t = t
        ---------------
        listType' :: C.CodeType -> Integer -> I.StateType
        listType' _ 0 = error "No index given"
        listType' t 1 = convType t
        listType' t n = listT $ listType' t (n-1)
        ---------------
        l_line = "line"
        v_line = var l_line
        l_lines = "lines"
        v_lines = var l_lines
        l_linetokens = "linetokens"
        v_linetokens = var l_linetokens
        l_infile = "infile"
        v_infile = var l_infile
        l_filename = "filename"
        p_filename = param l_filename string
        v_filename = var l_filename
        l_i = "i"
        v_i = var l_i
        l_j = "j"
        v_j = var l_j
