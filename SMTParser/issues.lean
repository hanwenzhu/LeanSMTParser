import SMTParser.QuerySMT

set_option auto.smt true
set_option auto.smt.trust true
set_option auto.smt.solver.name "cvc5"
set_option auto.smt.dumpHints true
set_option auto.smt.dumpHints.limitedRws true

set_option auto.smt.save false
set_option auto.smt.savepath "/Users/joshClune/Desktop/temp.smt"

set_option linter.setOption false

set_option trace.auto.smt.printCommands true
set_option trace.auto.smt.result true
set_option trace.auto.smt.proof true
set_option trace.auto.smt.parseTermErrors true
set_option auto.getHints.failOnParseError true
set_option trace.auto.smt.stderr true

set_option trace.querySMT.debug true
set_option duper.throwPortfolioErrors false
set_option querySMT.filterOpt 3

set_option duper.collectDatatypes true

-------------------------------------------------------------------------------------------
-- Issue: Adding the fact `h7` causes Duper to stop succeeding and start saturating

set_option trace.duper.printProof true in
example (Pos Neg Zero : Int → Prop)
  (h4 : ∀ x : Int, Pos x → Pos (x + 1))
  (h5 : Pos 1) : Pos 2 := by
  querySMT -- This problem works without `h7`

set_option trace.duper.saturate.debug true in
example (Pos Neg Zero : Int → Prop)
  (h4 : ∀ x : Int, Pos x → Pos (x + 1))
  (h5 : Pos 1)
  (h7 : ∀ x : Int, Pos x ↔ Neg (- x)) : Pos 2 := by
  sorry -- querySMT -- Duper saturates when `h7` is added
  -- Temporary fix: Only pass unsat core to duper
  -- Long term fix: Fix this behavior so duper can handle being given `h7`

-------------------------------------------------------------------------------------------
-- Issue: Duper doesn't natively know that `-x` = `0 - x`. So when `-x` appears in the initial
-- problem but is then translated to `0 - x` by the SMT parser, duper can wind up missing an essential fact

example (Pos Neg Zero : Int → Prop)
  (h4 : ∀ x : Int, Neg x → Neg (x - 1))
  (h5 : Neg (-1)) : Neg (-2) := by
  querySMT -- This problem works with `h4` in this simpler form

example (Pos Neg Zero : Int → Prop)
  (h4 : ∀ x : Int, Neg (- x) → Neg (-(x + 1)))
  (h5 : Neg (-1)) : Neg (- 2) := by
  have neededFact : ∀ x : Int, -x = 0 - x := sorry
  querySMT

example (Pos Neg Zero : Int → Prop)
  (h4 : ∀ x : Int, Neg (- x) → Neg ((- x) - 1))
  (h5 : Neg (-1)) : Neg (- 2) := by
  have neededFact : ∀ x : Int, -x = 0 - x := sorry
  querySMT

-------------------------------------------------------------------------------------------
-- `cvc5` doesn't get these

example (l : List Int) : l = [] ∨ ∃ x : Int, ∃ l' : List Int, l = x :: l' := by
 sorry -- querySMT -- `cvc5` times out

example : ∀ x : Int × Int, ∃ y : Int, ∃ z : Int, x = (y, z) := by
  sorry -- querySMT -- `cvc5` times out

-------------------------------------------------------------------------------------------
-- Currently the lean-auto/cvc5 connection can't handle selectors

whatsnew in
inductive myType2 (t : Type)
| const3 : t → myType2 t
| const4 : t → myType2 t

open myType2

example (t : Type) (x : myType2 t) : ∃ y : t, x = const3 y ∨ x = const4 y := by
  duper

example (t : Type) (x : myType2 t) : ∃ y : t, x = const3 y ∨ x = const4 y := by
  querySMT

-------------------------------------------------------------------------------------------
-- The first example works fine, but the second extremely similar one fails

example (l : List Int) (contains : List Int → Int → Prop)
  (h1 : ∀ x : Int, contains l x → x ≥ 0)
  (h2 : ∃ x : Int, ∃ y : Int, contains l x ∧ contains l y ∧ x + y < 0) : False := by
  skolemizeAll
  querySMT

-- This is failing because `l.contains x` is being transformed to `l.contains sk0 = true` where `true`
-- is of type Bool (as opposed to being `True` of type `Prop`). So the `builtInSymbolMap` that `parseTerm`
-- uses is seeing `true` in the SMT output and parsing it as `True` even though in this instance, it
-- needs to be registered as `true`
example (l : List Int) (h1 : ∀ x : Int, l.contains x → x ≥ 0)
  (h2 : ∃ x : Int, ∃ y : Int, l.contains x ∧ l.contains y ∧ x + y < 0) : False := by
  skolemizeAll
  sorry -- querySMT -- Det timeout caused by `decide True` in smtLemmas. Look into a better Prop->Bool coercion

-------------------------------------------------------------------------------------------
-- The SMT parser can now handle Bool->Prop coercions, but there are some cases where we seem to need
-- Prop->Bool coercions (when something originally of type Bool is changed to type Prop by lean-auto)

example (y : Bool) (myNot : Bool → Bool) (not_not : ∀ x : Bool, myNot (myNot x) = x)
  : y = myNot (myNot y) := by
  querySMT

-- failed to synthesize Decidable _b use `set_option diagnostics true` to get diagnostic information
-- The `_b` in the above error message is `x` in `not_not`
-- The issue is that we assert the following in the original problem:
--  `(assert (! (forall ((_b Bool)) (= (_myNot (_myNot _b)) _b)) :named valid_fact_0))`
-- When we see the above, it only makes sense that we'd interpret the `Bool` as `Prop`

-- In general, the strategy I used for Bool->Prop coercions should always be fine, but I'll
-- need a more involved strategy (maybe with genuine backtracking) to handle Prop->Bool coercions

-------------------------------------------------------------------------------------------
-- `smtLemma0` generated by this `querySMT` invocation follows from the negated goal. Need
-- to modify `querySMT` so that we are capable of proving smt lemmas that follow from the negated
-- goal

inductive myType3
| const5 : Unit → myType3

open myType3

example (x : myType3) : ∃ y : Unit, x = const5 y := by
  querySMT
  -- have smtLemma0 : ∀ (_p : PUnit.{1}), ¬x = const5 _p := by proveSMTLemma
  -- duper [*]


-------------------------------------------------------------------------------------------
/-
example (x y : Real) : x < y ∨ y ≤ x := by
  querySMT -- Fails because lean-auto doesn't depend on Mathlib and therefore doesn't know about Reals

example (x y z : Nat) : x < y → y < z → x < z := by
  querySMT -- TODO: Look into incorporating `zify` in the preprocessing (or a better version of it)
-/
-------------------------------------------------------------------------------------------
-- Integrate `skolemizeAll` with `querySMT`
