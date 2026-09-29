# LW-3 follow-up: contiguous distant patches

Baseline 7d1af22. Added explicit `--distant-mode patches`; default `rays` remains unchanged. Only the distant payload projection changes. Adjacent intervals merge only when original coarse color and range band match. Gaps and different bands never merge; no World identity is consulted. This is an angular appearance patch, not object identity. After merging, more than four patches still means PARTIAL/output_limited. Runtime observation_key, learning, priority and H are unchanged. Manifest sensor tag distinguishes lw-planar-patches-v1 from lw-planar-rays-v1 while retaining the existing compatibility wire schema.

## Completed run

Seed 20260928, disabled model field, three agents, thirty days: completed in 27.126 seconds. 23,040 steps, zero harvest, returns, learning or adopted models. Compared with the saved rays/disabled run, 11 packets changed, zero commands/results/bodies changed. Distances remain A37/B34/C0. acquisition_incomplete counts remain A3661/B3678/C3719, all involving distant PARTIAL. Therefore contiguous-ray duplication alone does not explain the persistent incompleteness.

Saved `lightweight_world_patches_disabled.jsonl.gz` and `lightweight_world_patches_audit.json` under tests/fixtures. Audit includes source hash and complete run summary.

## Incomplete comparison

The enabled run did not finish. A retry on Python 3.14.7 reported `Fatal Python error: _PyEval_EvalFrameDefault: Executing a cache` in World.cast. Python 3.11 attempts also terminated, including an anomalous TypeError within segment_hit; the underlying cause was not established. No complete enabled result or paired acceptance is claimed. Wall timings across Python versions are not compared. Local partial logs remain in ignored output. This task does not attempt to diagnose host/runtime instability.

## Validation and next boundary

Twelve lightweight tests passed on Python 3.14 before the later retry failures: new adjacency/gap/band/nonidentity/overflow tests plus existing World and comparison tests. No whole-repository suite or Luanti run. Implementation is opt-in and the completed disabled experiment is a negative result.

Next design question: observation_key currently requires ground + food + distant + landmarks complete for the full appearance key. Determine whether local food approach, landmark exploration and learning need the same acquisition boundary. Any split must keep learning's provenance and missing-data checks explicit; do not silently reclassify PARTIAL or override it using H. No such Runtime change is made here.
