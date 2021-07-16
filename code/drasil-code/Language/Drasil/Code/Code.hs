-- | Defines the 'Code' data type.
module Language.Drasil.Code.Code (
    Code(..),
    spaceToCodeType
    ) where

import qualified Language.Drasil as S (Space(..))

import GOOL.Drasil (CodeType(..))

import Text.PrettyPrint.HughesPJ (Doc)

-- | Represents the generated code as a list of file names and rendered code pairs.
newtype Code = Code { unCode :: [(FilePath, Doc)]}

-- | Default mapping between 'Space' and 'CodeType'.
spaceToCodeType :: S.Space -> [CodeType]
spaceToCodeType S.Integer       = [Integer]
spaceToCodeType S.Natural       = [Integer]
spaceToCodeType S.Radians       = [Double, Float]
spaceToCodeType S.Real          = [Double, Float]
spaceToCodeType S.Rational      = [Double, Float]
spaceToCodeType S.Boolean       = [Boolean]
spaceToCodeType S.Char          = [Char]
spaceToCodeType S.String        = [String]
spaceToCodeType (S.Vect s)      = map List (spaceToCodeType s)
spaceToCodeType (S.Array s)     = map Array (spaceToCodeType s)
spaceToCodeType (S.Actor s)     = [Object s]
spaceToCodeType (S.DiscreteD _) = map List (spaceToCodeType S.Rational)
spaceToCodeType (S.DiscreteS _) = map List (spaceToCodeType S.String)
spaceToCodeType S.Void          = [Void]
spaceToCodeType (S.Mapping i t) = undefined -- TODO: this needs to be a powerset? [Func (map spaceToCodeType i) (spaceToCodeType t)]
