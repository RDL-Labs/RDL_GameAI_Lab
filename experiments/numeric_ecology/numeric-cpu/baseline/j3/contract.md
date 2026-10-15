# J3 v1 — persistent binary bridge, shadow only

Baseline production remains `52a9422`; J2 complete reference `ccdba78`.
Julia 1.13.1 and the existing locked environment, Python 3.12.15, Ubuntu 24.04,
one thread. J3 chooses an isolated persistent subprocess with binary pipes;
JuliaCall embedding remains a candidate, not a requirement or a tested result.

Capture the SAME 180 World-second campaign as J0, off, with only experimental
observers wrapping geometry functions and the outer SocialWorld.packet. Save
the query/result trace of A/B/C at capture times 0, 60, 120 seconds. Return the
original Python primitive results and packets. Compare final summary excluding
only elapsed_seconds against an uninstrumented run. No World/runtime file edits.

The trace is World-side, not agent input. Query order and Python short-circuit
decisions are already determined by Python. This is NOT Julia packet generation,
live backend replacement, future-tick batching, or end-to-end World acceleration.
Capture all loaded aliases of the original functions before starting the run;
record patched modules, hashes, run/agent/observation/time and call counts.

Wire: little-endian Float64, fixed 9 doubles/query (kind 0 segment / 1 ray,
start x/z, vector x/z, circle x/z/radius, margin), maximum 100000 queries/request.
Request header `<4sQI`: RDL3, request id, count. Response header `<4sQIQQQQ`:
RDR3, matching id/count, conversion ns, kernel ns, allocated bytes, GC ns.
Each result `<Bd`: tag 0 miss, 1 false, 2 true, 3 distance. Non-distance payload 0.
Requests/responses are owned copies. No shared mutable result buffers or caches.
Invalid data, corrupt framing, timeout or process failure raise; no fallback.

Use J2 domain/strict discrete rules and abs(a-b)<=1e-12+1e-12*abs(b) for distance.
Additionally report bit-exact numeric output count/differences; tolerance alone
does not establish production replay compatibility. Save first mismatch.
Replay each saved snapshot through Python and Julia, repeat it, mutate a returned
list and confirm a new response and frozen inputs remain unchanged. Shadow
returns Python output even when Julia agrees; mismatches raise before promotion.

Benchmark five fresh process series per backend on the SAME runner; alternate
Python/Julia execution order. Each process uses the same nine saved snapshots,
30 repetitions per snapshot after one warm-up. Julia persists across all batches
in that process. No per-ray process or call. Include packing/copying, pipe transfer,
server validation/conversion, batch and result decoding in total time. File loading
is outside warm timing, startup/first valid result separately reported. Python
reference uses the same semantic input with no artificial serialization tax.
Server allocation/GC diagnostics are not Python allocation measures. Both
controllers use /usr/bin/time -v for max RSS, plus sampled parent+server RSS
at idle/after batches (NOT simultaneous peak memory). Report both, no summed
peak-RSS fiction. Performance and shadow double-execution times are separate.

Stop at J3. No Julia opt-in World backend, J4 600-second run, full-day campaign,
H/rho policy, learned model change or automatic adoption. If packing/round-trip
dominates, report this bridge as unsuitable and propose a later bridge/granularity
experiment instead of concealing overhead or claiming kernel-only speedup.
