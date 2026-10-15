# M00 initial Skyline probe — partial measurement

Source: isolated d49e2de runtime; no optimization applied. Julia 1.13.1,
Windows / raptorlake, one thread. Fixed seed04 initial position,95 objects,
subrays enabled. Spec SHA256 `97d7aab45cc709bc1a061c0e4868f7d9ddcc68afaebbab5f5565fb96040f7a5a`.

Five warmed batches of32 calls: median 2.1288ms/call,
range 2.0076–2.1835ms/call.
Each batch allocates151,502,848 bytes, or4,734,464 bytes/call.
Initial call includes compilation: 0.189871s.
Process peak RSS 465784832 bytes includes loading and profiling.
These timings overlapped the separate local30-day process and are exploratory,
not uncontended acceptance benchmarks. The local30-day timing also overlaps
this approximately eight-second tool invocation and must not be described as
an isolated machine measurement.

CPU profile:271 snapshots; JSON3 iteration/value extraction/populateinds and
symbol handling appear prominently inside skyline_fan. Sampled allocations also
include JSON3 object dictionaries and memory beneath skyline_fan. These inclusive
stack counts must not be summed as exclusive time percentages. Low-rate allocation
sampling produced1327 records; it is not an exact allocation-byte attribution.

The wrapper's inferred return is Dict{String,Any}. This alone does not establish
which internal values cause dispatch; further inference inspection is needed.
Next candidate comparison should separate horizontal-intersection reuse (C02)
from one-time concrete geometry conversion. Neither is yet implemented or adopted.

Scope limits: initial fixed observation only, not living-loop CPU attribution,
night/Sleep, full observation pipeline, or full M00 completion. Existing30-day
cloud/local inputs and sources were unchanged. No speedup claim.

Raw local files: outputs/lw-optimization/m00-skyline/measurements.json,
cpu.txt, allocations.txt, warntype.txt. The probe accepts a source directory and
frozen spec so later candidates can be measured on the same inputs.


Timing-context correction: the local30-day run was later confirmed to have
failed at19:18:26 JST, before this probe. The probe's raw scope label presumed
concurrency without a fresh process check and should not be read as evidence of
actual overlap. Treat the timings as exploratory regardless; no full-loop
performance conclusion comes from M00 alone.
