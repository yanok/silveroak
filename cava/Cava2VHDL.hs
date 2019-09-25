module Cava2VHDL where

import Data.List(nub)
import Control.Monad.State

import Cava
import qualified Datatypes
import ExtractionUtils

findInputs :: Datatypes.Coq_list Coq_cava -> [String]
findInputs = nub . concat . map findInputs' . decodeList

findInputs' :: Coq_cava -> [String]
findInputs' c =
  case c of
    Inv x -> findInputs' x
    And2 (Datatypes.Coq_pair i0 i1) -> findInputs' i0 ++ findInputs' i1
    Or2  (Datatypes.Coq_pair i0 i1) -> findInputs' i0 ++ findInputs' i1
    Delay x -> findInputs' x
    Signal name -> [decodeCoqString name]
    Output _ expr -> findInputs' expr

findOutputs :: Datatypes.Coq_list Coq_cava -> [String]
findOutputs = nub . concat . map findOutputs' . decodeList
    
findOutputs' :: Coq_cava -> [String]
findOutputs' c =
  case c of
    Inv x -> findOutputs' x
    And2 (Datatypes.Coq_pair i0 i1) -> findOutputs' i0 ++ findOutputs' i1
    Or2  (Datatypes.Coq_pair i0 i1) -> findOutputs' i0 ++ findOutputs' i1
    Delay x -> findInputs' x
    Signal _ -> []
    Output name _ -> [decodeCoqString name]

vhdlEntity :: String -> [String] -> [String] -> [String]
vhdlEntity name inputs outputs
  = ["entity " ++ name ++ " is",
      "  port("] ++
    insertSemicolons (map vhdlInput inputs ++ map vhdlOutput outputs) ++
    [
      "  );",
      "end entity " ++ name ++ ";"
    ]

vhdlInput :: String -> String
vhdlInput name = "    signal " ++ name ++ " : in bit"

vhdlOutput :: String -> String
vhdlOutput name = "    signal " ++ name ++ " : out bit"

insertSemicolons :: [String] -> [String]
insertSemicolons [] = []
insertSemicolons [x] = [x]
insertSemicolons (x:xs) = (x ++ ";") : insertSemicolons xs

type NetlistState = (Int, [String])

vhdlArchitecture :: Coq_cava -> State NetlistState Int
vhdlArchitecture (Inv x)
  = do xi <- vhdlArchitecture x
       (o, netlist) <- get
       let inv_inst = "  inv_" ++ show o ++ " : port map (i => net(" ++
                       show xi ++ "), o => net(" ++ show o ++ ");" 
       put (o+1, inv_inst:netlist)
       return o
