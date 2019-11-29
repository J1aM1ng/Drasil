{-# LANGUAGE PostfixOperators #-}

-- | The structure for a class of renderers is defined here.
module GOOL.Drasil.LanguageRenderer.LanguagePolymorphic (fileFromData, block, 
  pi, bool, int, float, double, char, string, fileType, listType, listInnerType,
  obj, enumType, void, inlineIf, increment, increment1, varDec, varDecDef, 
  listDec, listDecDef, objDecNew, objDecNewNoParams, comment, ifCond, for, 
  forEach, while, construct, param, method, getMethod, setMethod,privMethod, 
  pubMethod, constructor, docMain, function, mainFunction, docFunc, 
  docInOutFunc, intFunc, stateVar,stateVarDef, constVar, privMVar, pubMVar, 
  pubGVar, buildClass, enum, privClass, pubClass, docClass, commentedClass, 
  buildModule, buildModule', modFromData, fileDoc, docMod
) where

import Utils.Drasil (indent)

import GOOL.Drasil.CodeType (CodeType(..), isObject)
import GOOL.Drasil.Symantics (Label, KeywordSym(..),
  RenderSym(RenderFile, commentedMod), BlockSym(Block), 
  InternalBlock(..), BodySym(..), PermanenceSym(..), InternalPerm(..), 
  TypeSym(Type, getType, getTypeDoc, getTypeString), InternalType(..), 
  VariableSym(..), ValueSym(Value, litInt, valueOf, valueDoc, valueType), 
  NumericExpression(..), ValueExpression(newObj), InternalValue(..), 
  InternalStatement(..), 
  StatementSym(Statement, (&=), constDecDef, returnState), ScopeSym(..), 
  InternalScope(..), MethodTypeSym(MethodType, mType), ParameterSym(Parameter), 
  InternalParam(paramFromData), MethodSym(Method), 
  InternalMethod(intMethod, commentedFunc, methodDoc), 
  StateVarSym(StateVar), InternalStateVar(..), ClassSym(Class), 
  InternalClass(..), ModuleSym(Module), InternalMod(moduleDoc, updateModuleDoc),
  BlockComment(..))
import qualified GOOL.Drasil.Symantics as S (InternalFile(fileFromData), 
  TypeSym(float, void), StatementSym(varDec, varDecDef), 
  MethodTypeSym(construct), ParameterSym(param), 
  MethodSym(method, mainFunction), InternalMethod(intFunc), 
  StateVarSym(stateVar), ClassSym(buildClass, commentedClass), 
  InternalMod(modFromData))
import GOOL.Drasil.Data (Binding(..), Terminator(..), TypeData(..), td, 
  FileType)
import GOOL.Drasil.Helpers (angles, vibcat, vmap, emptyIfEmpty, toState,
  onStateValue, on2StateValues, onStateList, getInnerType, convType)
import GOOL.Drasil.LanguageRenderer (forLabel, addExt, blockDocD, stateVarDocD, 
  stateVarListDocD, methodListDocD, enumDocD, enumElementsDocD, moduleDocD, 
  fileDoc', docFuncRepr, commentDocD, commentedItem, functionDox, classDox, 
  moduleDox, getterName, setterName)
import GOOL.Drasil.State (GS, FS, MS, lensFStoGS, lensFStoMS, currMain, 
  putAfter, getPutReturn, getPutReturnFunc2, addFile, setMainMod, setFilePath, 
  getFilePath, setModuleName, getModuleName, getCurrMain, addParameter)

import Prelude hiding (break,print,last,mod,pi,(<>))
import Data.Maybe (maybeToList)
import Control.Applicative ((<|>))
import Control.Lens ((^.), over)
import Control.Lens.Zoom (zoom)
import Text.PrettyPrint.HughesPJ (Doc, text, empty, render, (<>), (<+>), parens,
  vcat, semi, equals, isEmpty)

block :: (RenderSym repr) => repr (Keyword repr) -> [repr (Statement repr)] -> 
  repr (Block repr)
block end sts = docBlock $ blockDocD (keyDoc end) (map (statementDoc . state) 
  sts)

bool :: (RenderSym repr) => repr (Type repr)
bool = typeFromData Boolean "Boolean" (text "Boolean")

int :: (RenderSym repr) => repr (Type repr)
int = typeFromData Integer "int" (text "int")

float :: (RenderSym repr) => repr (Type repr)
float = typeFromData Float "float" (text "float")

double :: (RenderSym repr) => repr (Type repr)
double = typeFromData Float "double" (text "double")

char :: (RenderSym repr) => repr (Type repr)
char = typeFromData Char "char" (text "char")

string :: (RenderSym repr) => repr (Type repr)
string = typeFromData String "string" (text "string")

fileType :: (RenderSym repr) => repr (Type repr)
fileType = typeFromData File "File" (text "File")

listType :: (RenderSym repr) => repr (Permanence repr) -> repr (Type repr) -> 
  repr (Type repr)
listType p t = typeFromData (List (getType t)) (render (keyDoc $ list p) ++ 
  "<" ++ getTypeString t ++ ">") (keyDoc (list p) <> angles (getTypeDoc t))

listInnerType :: (RenderSym repr) => repr (Type repr) -> repr (Type repr)
listInnerType = convType . getInnerType . getType

obj :: (RenderSym repr) => Label -> repr (Type repr)
obj n = typeFromData (Object n) n (text n)

enumType :: (RenderSym repr) => Label -> repr (Type repr)
enumType e = typeFromData (Enum e) e (text e)

void :: (RenderSym repr) => repr (Type repr)
void = typeFromData Void "void" (text "void")

pi :: (RenderSym repr) => repr (Value repr)
pi = valFromData Nothing S.float (text "Math.PI")

inlineIf :: (RenderSym repr) => repr (Value repr) -> repr (Value repr) -> 
  repr (Value repr) -> repr (Value repr)
inlineIf c v1 v2 = valFromData prec (valueType v1) (valueDoc c <+> text "?" <+> 
  valueDoc v1 <+> text ":" <+> valueDoc v2)
  where prec = valuePrec c <|> Just 0

increment :: (RenderSym repr) => repr (Variable repr) -> repr (Value repr) -> 
  repr (Statement repr)
increment vr vl = vr &= valueOf vr #+ vl

increment1 :: (RenderSym repr) => repr (Variable repr) -> repr (Statement repr)
increment1 vr = vr &= valueOf vr #+ litInt 1

varDec :: (RenderSym repr) => repr (Permanence repr) -> repr (Permanence repr) 
  -> repr (Variable repr) -> repr (Statement repr)
varDec s d v = stateFromData (permDoc (bind $ variableBind v) <+> getTypeDoc 
  (variableType v) <+> variableDoc v) Semi
  where bind Static = s
        bind Dynamic = d

varDecDef :: (RenderSym repr) => repr (Variable repr) -> repr (Value repr) -> 
  repr (Statement repr)
varDecDef vr vl = stateFromData (statementDoc (S.varDec vr) <+> equals 
  <+> valueDoc vl) Semi

listDec :: (RenderSym repr) => (repr (Value repr) -> Doc) -> 
  repr (Value repr) -> repr (Variable repr) -> repr (Statement repr)
listDec f sz v = stateFromData (statementDoc (S.varDec v) <> f sz) Semi

listDecDef :: (RenderSym repr) => ([repr (Value repr)] -> Doc) -> 
  repr (Variable repr) -> [repr (Value repr)] -> repr (Statement repr)
listDecDef f v vs = stateFromData (statementDoc (S.varDec v) <> f vs) Semi

objDecNew :: (RenderSym repr) => repr (Variable repr) -> [repr (Value repr)] -> 
  repr (Statement repr)
objDecNew v vs = S.varDecDef v (newObj (variableType v) vs)

objDecNewNoParams :: (RenderSym repr) => repr (Variable repr) -> 
  repr (Statement repr)
objDecNewNoParams v = objDecNew v []

comment :: (RenderSym repr) => repr (Keyword repr) -> Label -> 
  repr (Statement repr)
comment cs c = stateFromData (commentDocD c (keyDoc cs)) Empty

ifCond :: (RenderSym repr) => repr (Keyword repr) -> repr (Keyword repr) -> 
  repr (Keyword repr) -> [(repr (Value repr), repr (Body repr))] -> 
  repr (Body repr) -> repr (Statement repr)
ifCond _ _ _ [] _ = error "if condition created with no cases"
ifCond ifst elseif blEnd (c:cs) eBody = 
    let ifStart = keyDoc ifst
        elif = keyDoc elseif
        bEnd = keyDoc blEnd
        elseBody = bodyDoc eBody
        ifSect (v, b) = vcat [
          text "if" <+> parens (valueDoc v) <+> ifStart,
          indent $ bodyDoc b,
          bEnd]
        elseIfSect (v, b) = vcat [
          elif <+> parens (valueDoc v) <+> ifStart,
          indent $ bodyDoc b,
          bEnd]
        elseSect = emptyIfEmpty elseBody $ vcat [
          text "else" <+> ifStart,
          indent elseBody,
          bEnd]
    in stateFromData (vcat [
      ifSect c,
      vmap elseIfSect cs,
      elseSect]) Empty

for :: (RenderSym repr) => repr (Keyword repr) -> repr (Keyword repr) -> 
  repr (Statement repr) -> repr (Value repr) -> repr (Statement repr) -> 
  repr (Body repr) -> repr (Statement repr)
for bStart bEnd sInit vGuard sUpdate b = stateFromData (vcat [
  forLabel <+> parens (statementDoc (loopState sInit) <> semi <+> valueDoc 
    vGuard <> semi <+> statementDoc (loopState sUpdate)) <+> keyDoc bStart,
  indent $ bodyDoc b,
  keyDoc bEnd]) Empty

forEach :: (RenderSym repr) => repr (Keyword repr) -> repr (Keyword repr) -> 
  repr (Keyword repr) -> repr (Keyword repr) -> repr (Variable repr) -> 
  repr (Value repr) -> repr (Body repr) -> repr (Statement repr)
forEach bStart bEnd forEachLabel inLbl e v b = stateFromData
  (vcat [keyDoc forEachLabel <+> parens (getTypeDoc (variableType e) <+> 
    variableDoc e <+> keyDoc inLbl <+> valueDoc v) <+> keyDoc bStart,
  indent $ bodyDoc b,
  keyDoc bEnd]) Empty

while :: (RenderSym repr) => repr (Keyword repr) -> repr (Keyword repr) -> 
  repr (Value repr) -> repr (Body repr) -> repr (Statement repr)
while bStart bEnd v b = stateFromData (vcat [
  text "while" <+> parens (valueDoc v) <+> keyDoc bStart,
  indent $ bodyDoc b,
  keyDoc bEnd]) Empty

construct :: Label -> TypeData
construct n = td (Object n) n empty

param :: (RenderSym repr) => (repr (Variable repr) -> Doc) -> 
  repr (Variable repr) -> MS (repr (Parameter repr))
param f v = getPutReturn (addParameter (variableName v)) (paramFromData v (f v))

method :: (RenderSym repr) => Label -> Label -> repr (Scope repr) -> 
  repr (Permanence repr) -> repr (Type repr) -> [MS (repr (Parameter repr))] -> 
  repr (Body repr) -> MS (repr (Method repr))
method n c s p t = intMethod False n c s p (mType t)

getMethod :: (RenderSym repr) => Label -> repr (Variable repr) -> 
  MS (repr (Method repr))
getMethod c v = S.method (getterName $ variableName v) c public dynamic_ 
    (variableType v) [] getBody
    where getBody = oneLiner $ returnState (valueOf $ objVarSelf c v)

setMethod :: (RenderSym repr) => Label -> repr (Variable repr) -> 
  MS (repr (Method repr))
setMethod c v = S.method (setterName $ variableName v) c public dynamic_ S.void 
  [S.param v] setBody
  where setBody = oneLiner $ objVarSelf c v &= valueOf v

privMethod :: (RenderSym repr) => Label -> Label -> repr (Type repr) -> 
  [MS (repr (Parameter repr))] -> repr (Body repr) -> 
  MS (repr (Method repr))
privMethod n c = S.method n c private dynamic_

pubMethod :: (RenderSym repr) => Label -> Label -> repr (Type repr) -> 
  [MS (repr (Parameter repr))] -> repr (Body repr) -> 
  MS (repr (Method repr))
pubMethod n c = S.method n c public dynamic_

constructor :: (RenderSym repr) => Label -> Label -> 
  [MS (repr (Parameter repr))] -> repr (Body repr) -> MS (repr (Method repr))
constructor fName n = intMethod False fName n public dynamic_ (S.construct n)

docMain :: (RenderSym repr) => repr (Body repr) -> 
  MS (repr (Method repr))
docMain b = commentedFunc (docComment $ toState $ functionDox 
  "Controls the flow of the program" 
  [("args", "List of command-line arguments")] []) (S.mainFunction b)

function :: (RenderSym repr) => Label -> repr (Scope repr) -> 
  repr (Permanence repr) -> repr (Type repr) -> [MS (repr (Parameter repr))] -> 
  repr (Body repr) -> MS (repr (Method repr))
function n s p t = S.intFunc False n s p (mType t)

mainFunction :: (RenderSym repr) => repr (Type repr) -> Label -> 
  repr (Body repr) -> MS (repr (Method repr))
mainFunction s n = S.intFunc True n public static_ (mType S.void)
  [S.param (var "args" (typeFromData (List String) (render (getTypeDoc s) ++ 
  "[]") (getTypeDoc s <> text "[]")))]

docFunc :: (RenderSym repr) => String -> [String] -> Maybe String -> 
  MS (repr (Method repr)) -> MS (repr (Method repr))
docFunc desc pComms rComm = docFuncRepr desc pComms (maybeToList rComm)

docInOutFunc :: (RenderSym repr) => (repr (Scope repr) -> repr (Permanence repr)
    -> [repr (Variable repr)] -> [repr (Variable repr)] -> 
    [repr (Variable repr)] -> repr (Body repr) -> 
    MS (repr (Method repr)))
  -> repr (Scope repr) -> repr (Permanence repr) -> String -> 
  [(String, repr (Variable repr))] -> [(String, repr (Variable repr))] -> 
  [(String, repr (Variable repr))] -> repr (Body repr) -> 
  MS (repr (Method repr))
docInOutFunc f s p desc is [o] [] b = docFuncRepr desc (map fst is) [fst o] 
  (f s p (map snd is) [snd o] [] b)
docInOutFunc f s p desc is [] [both] b = docFuncRepr desc (map fst $ both : is) 
  [fst both | not ((isObject . getType . variableType . snd) both)] 
  (f s p (map snd is) [] [snd both] b)
docInOutFunc f s p desc is os bs b = docFuncRepr desc (map fst $ bs ++ is ++ os)
  [] (f s p (map snd is) (map snd os) (map snd bs) b)

intFunc :: (RenderSym repr) => Bool -> Label -> repr (Scope repr) -> 
  repr (Permanence repr) -> repr (MethodType repr) -> 
  [MS (repr (Parameter repr))] -> repr (Body repr) -> MS (repr (Method repr))
intFunc m n = intMethod m n ""

stateVar :: (RenderSym repr) => repr (Scope repr) -> repr (Permanence repr) ->
  repr (Variable repr) -> GS (repr (StateVar repr))
stateVar s p v = stateVarFromData $ stateVarDocD (scopeDoc s) (permDoc p) 
  (statementDoc (state $ S.varDec v))

stateVarDef :: (RenderSym repr) => repr (Scope repr) -> repr (Permanence repr) 
  -> repr (Variable repr) -> repr (Value repr) -> 
  GS (repr (StateVar repr))
stateVarDef s p vr vl = stateVarFromData $ stateVarDocD (scopeDoc s) (permDoc p)
  (statementDoc (state $ S.varDecDef vr vl))

constVar :: (RenderSym repr) => Doc -> repr (Scope repr) ->
  repr (Variable repr) -> repr (Value repr) -> 
  GS (repr (StateVar repr))
constVar p s vr vl = stateVarFromData $ stateVarDocD (scopeDoc s) p 
  (statementDoc (state $ constDecDef vr vl))

privMVar :: (RenderSym repr) => repr (Variable repr) -> 
  GS (repr (StateVar repr))
privMVar = S.stateVar private dynamic_

pubMVar :: (RenderSym repr) => repr (Variable repr) -> 
  GS (repr (StateVar repr))
pubMVar = S.stateVar public dynamic_

pubGVar :: (RenderSym repr) => repr (Variable repr) -> 
  GS (repr (StateVar repr))
pubGVar = S.stateVar public static_

buildClass :: (RenderSym repr) => (Label -> Doc -> Doc -> Doc -> Doc -> Doc) -> 
  (Label -> repr (Keyword repr)) -> Label -> Maybe Label -> repr (Scope repr) 
  -> [GS (repr (StateVar repr))] -> 
  [MS (repr (Method repr))] -> FS (repr (Class repr))
buildClass f i n p s vs fs = classFromData (on2StateValues (f n parent 
  (scopeDoc s)) (onStateList (stateVarListDocD . map stateVarDoc) (map (zoom lensFStoGS) vs)) 
  (onStateList (methodListDocD . map methodDoc) (map (zoom lensFStoMS) fs)))
  where parent = case p of Nothing -> empty
                           Just pn -> keyDoc $ i pn

enum :: (RenderSym repr) => Label -> [Label] -> repr (Scope repr) -> 
  FS (repr (Class repr))
enum n es s = classFromData (toState $ enumDocD n (enumElementsDocD es False) 
  (scopeDoc s))

privClass :: (RenderSym repr) => Label -> Maybe Label -> 
  [GS (repr (StateVar repr))] -> 
  [MS (repr (Method repr))] -> FS (repr (Class repr))
privClass n p = S.buildClass n p private

pubClass :: (RenderSym repr) => Label -> Maybe Label -> 
  [GS (repr (StateVar repr))] -> [MS (repr (Method repr))] -> 
  FS (repr (Class repr))
pubClass n p = S.buildClass n p public

docClass :: (RenderSym repr) => String -> FS (repr (Class repr))
  -> FS (repr (Class repr))
docClass d = S.commentedClass (docComment $ toState $ classDox d)

commentedClass :: (RenderSym repr) => FS (repr (BlockComment repr))
  -> FS (repr (Class repr)) -> FS (repr (Class repr))
commentedClass cmt cs = classFromData (on2StateValues (\cmt' cs' -> 
  commentedItem (blockCommentDoc cmt') (classDoc cs')) cmt cs)

buildModule :: (RenderSym repr) => Label -> [repr (Keyword repr)] -> 
  [MS (repr (Method repr))] -> [FS (repr (Class repr))] -> 
  FS (repr (Module repr))
buildModule n ls ms cs = S.modFromData n getCurrMain (on2StateValues 
  (moduleDocD (vcat $ map keyDoc ls)) (onStateList (vibcat . map classDoc) cs) 
  (onStateList (methodListDocD . map methodDoc) (map (zoom lensFStoMS) ms)))

buildModule' :: (RenderSym repr) => Label -> [MS (repr (Method repr))] -> 
  [FS (repr (Class repr))] -> FS (repr (Module repr))
buildModule' n ms cs = S.modFromData n getCurrMain (onStateList (vibcat . map 
  classDoc) (if null ms then cs else pubClass n Nothing [] ms : cs))

modFromData :: Label -> (Doc -> Bool -> repr (Module repr)) -> FS Bool -> 
  FS Doc -> FS (repr (Module repr))
modFromData n f m d = putAfter (setModuleName n) (on2StateValues f d m)

fileDoc :: (RenderSym repr) => FileType -> String -> repr (Block repr) -> 
  repr (Block repr) -> FS (repr (Module repr)) -> FS (repr (RenderFile repr))
fileDoc ft ext topb botb m = S.fileFromData ft (onStateValue (addExt ext) 
  getModuleName) (updateModuleDoc (\d -> emptyIfEmpty d (fileDoc' (blockDoc 
  topb) d (blockDoc botb))) m)

docMod :: (RenderSym repr) => String -> [String] -> String -> 
  FS (repr (RenderFile repr)) -> FS (repr (RenderFile repr))
docMod d a dt = commentedMod (docComment $ moduleDox d a dt <$> getFilePath)

fileFromData :: (RenderSym repr) => (repr (Module repr) -> FilePath -> 
  repr (RenderFile repr)) -> FileType -> FS FilePath -> 
  FS (repr (Module repr)) -> FS (repr (RenderFile repr))
fileFromData f ft fp m = getPutReturnFunc2 m fp (\s mdl fpath -> (if isEmpty 
  (moduleDoc mdl) then id else (if snd s ^. currMain then over lensFStoGS (setMainMod fpath) else id) . over lensFStoGS (addFile ft fpath) . setFilePath fpath) s) f