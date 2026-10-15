# CPU numeric storage experiment — stage 1

Based on fixed runtime 5b09a58c3009f59044cc08d2a551f939a3fa7790 and the local 30-agent / 3-day experiment. This copy does not modify the original repository or completed benchmark results.

## Implemented

- Stable, one-based agent slots in IDS order. Inventory, Body, position, hearing and inbox containers use vectors instead of String-keyed state dictionaries.
- Numeric integer indexing can be used directly; a String-to-index boundary keeps existing decision code compatible.
- Selected action names are stored as explicit UInt16 codes in NumericPlans. Codes are stable in ACTION_LABELS order, with zero reserved for an unset plan. Unknown actions fail instead of silently acquiring a code.
- Existing execution logic receives decoded plans, preserving the current model's behavior.

## Scope and limitations

This is a CPU storage migration, not a GPU backend or a completely numeric model. MB records, observations, messages, plan payloads and much decision logic still contain strings and dynamic dictionaries. The label lookup table is intentionally retained at the compatibility boundary. Body and position values already were numeric in the baseline; this change replaces their String-keyed containers with contiguous vectors.

NumericPlans currently copies and encodes/decodes plans, so this bridge may cost time. No speedup is promised. Removing boundary conversions and introducing typed numeric observations/MB payloads are subsequent migrations that require their own parity checks. GPU readiness will additionally require eliminating Any/dictionaries in kernel data and specifying deterministic conflict resolution.

## Verification

storage_checks.jl tests all 30 slots, direct numeric access, missing IDs, independent copies and action round-trips. parity.jl runs an unchanged one-day scenario through each version. The parity fixtures use the original three agents and the first three entries of the same experiment spec; source itself retains all 30 agents. This does not constitute a 30-agent full-duration parity test.

Run test.ps1 for both one-day scenarios using the locally installed Julia runtime. Run storage_checks.jl with source/julia as the Julia project. See validation.json for measured results.

Changed runtime files: source/social_loop/numeric_storage.jl, source/social_loop/run.jl, source/lw_day/run.jl.
