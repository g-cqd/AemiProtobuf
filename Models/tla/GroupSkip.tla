---------------------------- MODULE GroupSkip ----------------------------
(***************************************************************************)
(* The group-skipping loop of WireReader.skipGroup (Sources/AemiProtobufCore/WireReader+Skip.swift), over every  *)
(* token sequence up to MaxLen. A token is a scalar field, a start-group or an end-group of field n.             *)
(*                                                                                                               *)
(* The model is the algorithm, not the Swift: roadmap 0013 pairs it with an exhaustive Swift test that runs the  *)
(* real reader over the same sequences and checks the same oracle.                                               *)
(*                                                                                                               *)
(* Checked: the open-group stack never passes the depth limit, every run ends, and the loop accepts exactly the  *)
(* inputs an independent definition of "a balanced, matching, shallow-enough group" accepts. The independent     *)
(* definition does not use a stack: it counts, and it cancels adjacent start/end pairs.                          *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Numbers,   \* the field numbers that appear
          MaxDepth,  \* WireLimits.maxDepth
          MaxLen     \* longest input enumerated

Scalar == <<"scalar", 0>>
Tokens == {Scalar} \cup {<<k, n>> : k \in {"start", "end"}, n \in Numbers}
AllInputs == UNION {[1..k -> Tokens] : k \in 0..MaxLen}

VARIABLES input,   \* the tokens after the opening start-group
          opened,  \* the number of the group skipField was called on
          base,    \* the reader's own depth when skipField was called
          pos,     \* tokens consumed
          stack,   \* open groups, innermost last
          status   \* "running" or the way the loop ended

vars == <<input, opened, base, pos, stack, status>>

Init ==
    /\ input \in AllInputs
    /\ opened \in Numbers
    /\ base \in 0..MaxDepth
    /\ pos = 0
    /\ stack = <<opened>>
    \* The code checks the opening group against the limit before it reads anything.
    /\ status = IF base + 1 > MaxDepth THEN "depth" ELSE "running"

Finish(s, st) == /\ status' = st /\ stack' = s

Step ==
    /\ status = "running"
    /\ IF pos = Len(input)
        THEN /\ status' = "truncated" /\ UNCHANGED <<pos, stack>>
        ELSE LET t == input[pos + 1] IN
            /\ pos' = pos + 1
            /\ CASE t[1] = "scalar" -> UNCHANGED <<stack, status>>
                 [] t[1] = "start" ->
                      IF base + Len(stack) + 1 > MaxDepth
                          THEN Finish(stack, "depth")
                          ELSE UNCHANGED status /\ stack' = Append(stack, t[2])
                 [] t[1] = "end" ->
                      IF t[2] # stack[Len(stack)]
                          THEN Finish(stack, "mismatch")
                          ELSE IF Len(stack) = 1
                              THEN Finish(<<>>, "ok")
                              ELSE UNCHANGED status /\ stack' = SubSeq(stack, 1, Len(stack) - 1)
    /\ UNCHANGED <<input, opened, base>>

Done == status # "running" /\ UNCHANGED vars

Next == Step \/ Done

Spec == Init /\ [][Next]_vars /\ WF_vars(Step)

(***************************************************************************)
(* The independent definition.                                              *)
(***************************************************************************)

Whole == <<<<"start", opened>>>> \o input

IsStart(t) == t[1] = "start"
IsEnd(t) == t[1] = "end"
NotScalar(t) == t[1] # "scalar"
Height(s, i) == Len(SelectSeq(SubSeq(s, 1, i), IsStart)) - Len(SelectSeq(SubSeq(s, 1, i), IsEnd))

\* The group closes where the count of opens minus closes first returns to zero.
CloseAt == IF \E i \in 1..Len(Whole) : Height(Whole, i) = 0
              THEN CHOOSE i \in 1..Len(Whole) : Height(Whole, i) = 0 /\ \A j \in 1..(i - 1) : Height(Whole, j) > 0
              ELSE 0

Closed == SubSeq(Whole, 1, CloseAt)

\* Cancel one adjacent start n / end n pair, scalars first. Repeated Len times, what is left is empty exactly when the
\* group is well nested and each end names the group it closes.
Strip(s) == SelectSeq(s, NotScalar)
Cancel(s) ==
    IF \E i \in 1..(Len(s) - 1) : IsStart(s[i]) /\ IsEnd(s[i + 1]) /\ s[i][2] = s[i + 1][2]
        THEN LET i == CHOOSE i \in 1..(Len(s) - 1) : IsStart(s[i]) /\ IsEnd(s[i + 1]) /\ s[i][2] = s[i + 1][2]
             IN SubSeq(s, 1, i - 1) \o SubSeq(s, i + 2, Len(s))
        ELSE s
Reduced[k \in 0..(MaxLen + 1)] == IF k = 0 THEN Strip(Closed) ELSE Cancel(Reduced[k - 1])

MaxHeight == IF CloseAt = 0 THEN 0 ELSE CHOOSE m \in 0..(MaxLen + 1) :
    /\ \E i \in 1..CloseAt : Height(Whole, i) = m
    /\ \A i \in 1..CloseAt : Height(Whole, i) <= m

OracleAccepts ==
    /\ CloseAt > 0
    /\ Reduced[MaxLen + 1] = <<>>
    /\ base + MaxHeight <= MaxDepth

(***************************************************************************)
(* Properties.                                                              *)
(***************************************************************************)

DepthBounded == status = "running" => base + Len(stack) <= MaxDepth

\* The loop and the definition agree, and an accepted group leaves exactly the tokens after its close unread.
Agrees ==
    status # "running" =>
        /\ (status = "ok") <=> OracleAccepts
        /\ status = "ok" => pos = CloseAt - 1

Terminates == <>(status # "running")

=============================================================================
