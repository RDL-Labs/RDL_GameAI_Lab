# Typed Skyline input — P candidate, one-day candidate accepted for broader comparison

Change: prepare the current World's immutable static geometry once as concrete
NamedTuple values, rather than repeatedly iterating JSON3 objects in skyline_fan.
The sensor loop, arithmetic, elevations, subrays, range, output and source remain
unchanged. Input order is retained. This is separate from C02 intersection reuse.
Dynamic hazards, actors, cargo, food stock and ground wear are not cached here.
A future change to static obstacle geometry must rebuild this value array.

Local tests:149 comparisons PASS, including95-object frozen World at72 poses,
both subray modes, low foreground/tall background, inside object, tangent, range
edge and equal-distance ordering. This is finite evidence, not all geometry.

Five alternating warmed samples,32 calls each, Windows Julia1.13.1, one thread:
- Old median: 0.0653786s,
  allocated151,502,848 bytes/batch.
- Candidate median: 0.0033614s,
  allocated314,368 bytes/batch.
- Local ratio: 19.45x.
- One-time conversion after warmup: 3.3e-05s,
  49543 bytes.

All sample checksums agree. These are sensory-local measurements, not an LW
speed ratio or an access-violation fix. No profiler in these timing samples.

A same-spec seed04 one-day old/candidate comparison is running sequentially in
fresh processes under outputs/lw-optimization/geometry-life. Base d49e2de;
candidate differs only in skyline preparation and its living-loop callsite.
Pending goal-threshold changes are excluded. Sources of both existing30-day
acceptance runs are untouched. Full-life result equality, resource audit,
end-to-end time and process RSS remain pending; candidate is not yet adopted.


## One-day integrated result

Both fresh Windows Julia1.13.1 processes exited0. Old/candidate result.json are
byte-identical, with51,840 operations each. Independent saved-result audit passed
initial/daily/terminal food conservation and final body/position/inventory versus
last-night state:124=112 ground+6 shared+0 held+6 consumed.

| Metric | Old | Candidate |
|---|---:|---:|
| Process wall seconds, includes loading and save |182.4125|60.3111|
| Native call seconds, includes compilation |175.5278|53.9385|
| Cumulative allocation bytes |286556937119|41546507113|
| GC seconds |21.0417|3.8729|
| Fresh-process peak RSS bytes |1011204096|1035472896|

This is about3.02x process speed and85.5% fewer allocated bytes for this one
paired run, not a general speed guarantee. Peak RSS increased slightly; do not
claim retained-memory improvement. All saved fields including H/experience/
Sleep/body/resource state agree, but no post-Sleep model use occurred here.
Broader multi-day/two-seed acceptance is still required. No claim of repairing
the prior Windows access violation; a one-day successful run cannot prove it.

The earlier statement that the comparison was pending is historical. Source
hashes are retained in both native manifests, raw measurements and result hashes
under outputs/lw-optimization/geometry-life. Pending threshold configuration is
not in either comparison source. No remote push or workflow change was made.
