(****************************************************************************)
(* Copyright 2021 The Project Oak Authors                                   *)
(*                                                                          *)
(* Licensed under the Apache License, Version 2.0 (the "License")           *)
(* you may not use this file except in compliance with the License.         *)
(* You may obtain a copy of the License at                                  *)
(*                                                                          *)
(*     http://www.apache.org/licenses/LICENSE-2.0                           *)
(*                                                                          *)
(* Unless required by applicable law or agreed to in writing, software      *)
(* distributed under the License is distributed on an "AS IS" BASIS,        *)
(* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *)
(* See the License for the specific language governing permissions and      *)
(* limitations under the License.                                           *)
(****************************************************************************)

Require Import Coq.Arith.PeanoNat.
Require Import Coq.Lists.List.
Require Import Cava.Core.Core.
Require Import Cava.Semantics.Combinational.
Require Import Cava.Semantics.Equivalence.
Require Import Cava.Semantics.Simulation.
Require Import Cava.Semantics.Loopless.
Require Import Cava.Semantics.WeakEquivalence.
Require Import Cava.Lib.CircuitTransforms.
Require Import Cava.Lib.Combinators.
Require Import Cava.Lib.Multiplexers.
Import ListNotations Circuit.Notations.

Section WithCava.
  Context `{semantics : Cava}.
  (* make a circuit with repeated delays for each signal *)
  Fixpoint ndelays {t : type} (r : list (@value combType t)) : Circuit t t :=
    match r with
    | [] => Id
    | r0 :: r => ndelays r >==> DelayInit r0
    end.
End WithCava.

Definition retimed {i o} (n m : nat) (c1 c2 : Circuit i o) : Prop :=
  (* there exists some way of converting between the loop states of c1 and c2 *)
  exists (proj21 : value (loops_state c2) -> value (loops_state c1))
    (proj12 : value (loops_state c1) -> value (loops_state c2)),
    (forall x, proj12 (proj21 x) = x)
    (* ..and there exist two sets of delay values, one for the state and one for
       the outputs *)
    /\ exists (or : list (value o)) (sr : list (value (loops_state c2))),
      (* ...and loopless c1 is equivalent to loopless c2 composed with the delay
         circuits and the state projections *)
      cequiv (loopless c1)
             (Second (Comb proj12)
                     >==> loopless c2
                     >==> Par (ndelays or) (ndelays sr)
                     >==> Second (Comb proj21))
      (* ...and the number of output delays is n *)
      /\ length or = n
      (* ...and the number of loop state delays is m *)
      /\ length sr = m.
