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

Require Import Coq.Lists.List.
Require Import Coq.ZArith.ZArith.
Require Import ExtLib.Structures.Monoid.
Require Import ExtLib.Data.List.

Require Import Cava.Types.
Require Import Cava.Expr.
Require Import Cava.Semantics.

(* Naming and parameter choices follow OpenTitan conventions *)
Definition TL_AW  := 32.
Definition TL_DW  := 32.
Definition TL_AIW := 8.
Definition TL_DIW := 1.
Definition TL_DUW := 4.
Definition TL_DBW := 4. (* (TL_DW>>3). *)
Definition TL_SZW := 2. (* $clog2($clog2(TL_DBW)+1). *)

Notation BitVec n := (Vec Bit n).

(* (1* typedef struct packed { *1) *)
(* (1*   logic                         a_valid; *1)   1 *)
(* (1*   tl_a_op_e                     a_opcode; *1)  3 *)
(* (1*   logic                  [2:0]  a_param; *1)   3 *)
(* (1*   logic  [top_pkg::TL_SZW-1:0]  a_size; *1)    2 *)
(* (1*   logic  [top_pkg::TL_AIW-1:0]  a_source; *1)  8 *)
(* (1*   logic   [top_pkg::TL_AW-1:0]  a_address; *1) 32 *)
(* (1*   logic  [top_pkg::TL_DBW-1:0]  a_mask; *1)    4 *)
(* (1*   logic   [top_pkg::TL_DW-1:0]  a_data; *1)    32 *)
(* (1*   tl_a_user_t                   a_user; *1)    16 *)
(* (1*   logic                         d_ready; *1)   1 *)
(* (1* } tl_h2d_t; *1)
=102 *)
Definition tl_h2d_t :=
  Bit **
  BitVec 3 **
  BitVec 3 **
  BitVec TL_SZW **
  BitVec TL_AIW **
  BitVec TL_AW **
  BitVec TL_DBW **
  BitVec TL_DW **
  BitVec 16 **
  Bit.

(* typedef struct packed { *)
(*   logic                         d_valid; *)
(*   tl_d_op_e                     d_opcode; *)
(*   logic                  [2:0]  d_param; *)
(*   logic  [top_pkg::TL_SZW-1:0]  d_size; *)
(*   logic  [top_pkg::TL_AIW-1:0]  d_source; *)
(*   logic  [top_pkg::TL_DIW-1:0]  d_sink; *)
(*   logic   [top_pkg::TL_DW-1:0]  d_data; *)
(*   logic  [top_pkg::TL_DUW-1:0]  d_user; *)
(*   logic                         d_error; *)
(*   logic                         a_ready; *)
(* } tl_d2h_t; *)

Definition tl_d2h_t :=
  Bit **
  BitVec 3 **
  BitVec 3 **
  BitVec 2 **
  BitVec 8 **
  BitVec 1 **
  BitVec 32 **
  BitVec 4 **
  Bit **
  Bit.

Section Var.
  Import ExprNotations.
  Context {var : tvar}.

  Definition False := Constant (false: denote_type Bit).

  (* typedef enum logic [2:0] { *)
  (*   PutFullData    = 3'h 0, *)
  (*   PutPartialData = 3'h 1, *)
  (*   Get            = 3'h 4 *)
  (* } tl_a_op_e; *)
  Definition tl_a_op_e      := Vec Bit 3.
  Definition PutFullData    := Constant (0: denote_type tl_a_op_e).
  Definition PutPartialData := Constant (1: denote_type tl_a_op_e).
  Definition Get            := Constant (4: denote_type tl_a_op_e).

  (* typedef enum logic [2:0] { *)
  (*   AccessAck     = 3'h 0, *)
  (*   AccessAckData = 3'h 1 *)
  (* } tl_d_op_e; *)
  Definition tl_d_op_e     := Vec Bit 3.
  Definition AccessAck     := Constant (0: denote_type tl_d_op_e).
  Definition AccessAckData := Constant (1: denote_type tl_d_op_e).

  Axiom prim_and :
    forall {s1 s2},
    Circuit s1 [] Bit ->
    Circuit s2 [] Bit ->
    Circuit (s1++s2) [] Bit.
  Notation "x && y" := (prim_and x y) (in custom expr at level 20, left associativity) : expr_scope.

  Axiom prim_or :
    forall {s1 s2},
    Circuit s1 [] Bit ->
    Circuit s2 [] Bit ->
    Circuit (s1++s2) [] Bit.
  Notation "x || y" := (prim_or x y) (in custom expr at level 20, left associativity) : expr_scope.

  Axiom prim_not :
    forall {s1 },
    Circuit s1 [] Bit ->
    Circuit s1 [] Bit.
  Notation "! x" := (prim_not x) (in custom expr at level 20) : expr_scope.

  Axiom prim_eq :
    forall {s1 s2 t},
    Circuit s1 [] t ->
    Circuit s2 [] t ->
    Circuit (s1++s2) [] Bit.
  Notation "x == y" := (prim_eq x y) (in custom expr at level 19, left associativity) : expr_scope.

  Axiom slice :
    forall {t n} (start len: nat), Circuit [] [Vec t n] (Vec t len).

  Definition io_req :=
    Bit **          (* write *)
    Bit **          (* read *)
    BitVec TL_AW ** (* address *)
    BitVec TL_DW ** (* write_data *)
    BitVec TL_DBW   (* write_mask *)
    .

  Definition tlul_adapter_reg : Circuit _ [tl_h2d_t; BitVec TL_DW; Bit] (tl_d2h_t ** io_req) := {{
    fun incoming_tlp read_data error =>

    let
      '(a_valid
      , a_opcode
      , a_param
      , a_size
      , a_source
      , a_address
      , a_mask
      , a_data
      , a_user
      ; d_ready) := incoming_tlp in

    let/delay '(reqid, reqsz, rspop, error, outstanding, we_o; re_o) :=

      let a_ack := a_valid && !outstanding in
      let d_ack := outstanding && d_ready in

      let rd_req := a_ack && a_opcode == `Get` in
      let wr_req := a_ack &&
        (a_opcode == `PutFullData` || a_opcode == `PutPartialData`) in

      (* TODO(blaxill): skipping malformed tl packet detection *)
      let err_internal := `False` in
      let error_i := `False` in

      let '(reqid, reqsz, rspop, error; outstanding) :=
        if a_ack then
          ( a_source
          , a_size
          , if rd_req then `AccessAckData` else `AccessAck`
          , error_i || err_internal
          , `False`
          )
        else
          (reqid, reqsz, rspop, error, if d_ack then `False` else outstanding)
      in

      let we_o := wr_req && !err_internal in
      let re_o := rd_req && !err_internal in

      (reqid, reqsz, rspop, error, outstanding, we_o, re_o)
      initially (0,(0,(0,(false,(false,(false,false)))))) : denote_type (BitVec _ ** BitVec _ ** BitVec _ ** Bit ** Bit ** Bit ** Bit)
    in

    let wdata_o := a_data in
    let be_o    := a_mask in

    ( ( outstanding
      , rspop
      , `Constant (0:denote_type (BitVec _))`
      , reqsz
      , reqid
      , `Constant (0:denote_type (BitVec _))`
      , read_data
      , `Constant (0:denote_type (BitVec _))`
      , error
      , !outstanding
      )
    , (we_o, re_o, a_address, a_data, a_mask)
    )

  }}.

End Var.
