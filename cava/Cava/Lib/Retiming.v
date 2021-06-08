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
Require Import Cava.Lib.CircuitTransforms.
Import ListNotations Circuit.Notations.

(* Define a restricted type format for the delay circuits to work with *)
Section WithCava.
  Context `{semantics : Cava}.
  (* gives the shape of a collection of signals *)
  Inductive itype : Type :=
  | ione (t : SignalType)
  | ipair (i1 i2 : itype)
  .

  (* gives the Gallina tuple for the collection of signals specified *)
  Fixpoint ivalue (i : itype) : Type :=
    match i with
    | ione t => signal t
    | ipair a b => ivalue a * ivalue b
    end.
End WithCava.

Section WithCava.
  Context `{semantics : Cava}.

  (* make a circuit with one delay for each signal, given the delays' reset
     values *)
  Fixpoint delays (t : itype)
    : ivalue (signal:=combType) t -> Circuit (ivalue t) (ivalue t) :=
    match t with
    | ione t => DelayInit
    | ipair a b =>
      fun resetvals =>
        Par (delays a (fst resetvals)) (delays b (snd resetvals))
    end.

  (* get the value stored in the 1-delay circuit *)
  Fixpoint delays_get {t : itype}
    : forall {resetvals}, circuit_state (delays t resetvals) -> ivalue t :=
    match t with
    | ione _ => fun _ => snd
    | ipair _ _ => fun _ st => (delays_get (fst st), delays_get (snd st))
    end.

  (* make a circuit with repeated delays for each signal, given the delays'
     reset values for each layer *)
  Fixpoint ndelays (t : itype) (resetvals : list (ivalue (signal:=combType) t))
    : Circuit (ivalue t) (ivalue t) :=
    match resetvals with
    | [] => Id
    | r0 :: resetvals => ndelays t resetvals >==> delays t r0
    end.

  (* get all the values stored in the n-delay circuit *)
  Fixpoint ndelays_get {t : itype} {resetvals}
    : circuit_state (ndelays t resetvals) -> list (ivalue t) :=
    match resetvals with
    | [] => fun _ => []
    | _ :: _ => fun st => delays_get (snd st) :: ndelays_get (fst st)
    end.
End WithCava.

Definition retimed {i o} (n : nat) (c1 c2 : Circuit i (ivalue o)) : Prop :=
  exists resetvals,
    length resetvals = n
    /\ cequiv c1 (c2 >==> ndelays o resetvals).