# Fast / Deep One-Cycle Reference Evidence

**Status:** F2 Runtime / HTTP evidence complete

## Proven Chain

```text
day 1
3 accepted Experience records
-> S1 fixed window
-> S2 Profiles
-> S3 Deep Similarity
-> one shadow CandidateRelation

day 2
accepted current Experience
-> F1 L0/L1 retrieval
-> same CandidateRelation rediscovered
```

The recovered result retains the candidate ID, Sleep cycle, and all three day-1
source Experience IDs. Raw Experience remains present and distinct from the
candidate. p5 receives the same chain through read-only GET snapshots.

## Finite Source Selection

F1 score ordering remains unchanged. When `top_k >= 2`, selection reserves one
slot for the best eligible raw Experience and one for the best eligible Sleep
candidate, then fills remaining slots by global rank. This prevents one source
class from disappearing from the comparison surface; it does not increase a
candidate's similarity score or grant authority.

## Non-Intervention

```text
retrieved candidate
!= new candidate
!= review
!= action influence
!= E / H
!= M_B admission
!= T1
```

The day-2 action is byte-equivalent before and after retrieval. This evidence
stops at rediscovery and provenance inspection.
