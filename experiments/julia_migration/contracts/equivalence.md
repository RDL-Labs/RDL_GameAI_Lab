# Frozen J0–J2 contract (before measurements)

J0: three independent 180 World-second events/off pairs, alternating order,
one second observations, human_scale_v1, movement inertia, same inherited
campaign configuration, three agents. Exclude ONLY root `elapsed_seconds`
from summary equality. Events audit is retained; off has no operation audit.
Final-state equality is not a proof of all intermediate actions being equal.
Profile a separate off worker with cProfile; report exclusive time categories
and cumulative functions separately (cumulative times overlap). No nighttime
or Sleep-performance inference from this daytime window.

J2: copy ray_hit and segment_hit formula/order from the baseline Git blob.
Float64, no fast-math, no spatial index, no threading. Finite coordinates in
[-10000,10000], radius [0,10000], margin [0,10000]; ray direction unit length
within 1e-12; segment endpoints may coincide. Strict hit/miss and nearest
object index/order; distance comparison abs(a-b) <= 1e-12 + 1e-12*abs(b).
These are a new geometry contract, not relaxation of a portable replay rule.
Existing source functions do not validate malformed inputs: the NEW wrapper
rejects wrong dimensions, negative radius/margin, zero/nonunit ray directions,
nonfinite values and out-of-domain inputs. No equivalence claim outside domain.

Fixed boundary cases plus 1000 seeded Python-generated queries; Julia reads
their serialized values, not its own seeded reconstruction. Additional nearest
ties preserve first occurrence. Returned arrays are fresh; inputs unchanged.
Hashes cover input/expected JSONL and groups; source Git blob is recorded.

Benchmark batches 23 (one baseline World's 23-object cast-sized workload) and
1024 (synthetic enlarged workload); NOT a measured whole-observation batch.
Both implementations return a fresh result array. Parsed/validated input
conversion measured separately; immutable queries require no state restore.
Three fresh process series per language, alternating language order. Startup
through first valid result is subprocess wall time; Julia first invocation
also recorded. Repeated times are profiler-free. Python tracemalloc and Julia
allocation measurements use different instruments and are not directly ratios.
Linux process max RSS uses the same resource API, separate from kernel memory.

The planned maintenance check adds endpoint-nextafter and duplicate-nearest
cases after the first passing implementation, keeping all original cases.
No production backend enablement, J3 or R1/R2 in this task.
