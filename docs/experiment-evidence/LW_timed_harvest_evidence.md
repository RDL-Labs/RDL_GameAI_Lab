# LW timed harvest phase

Baseline a118098. Added a separate opt-in `integrations.lightweight.timed_harvest` runner and HarvestCampaign subclass. Default World runner and legacy Runtime are unchanged. This action phase is not Core M_delta and does not use H.

## Contract

During exploration, current complete Food acquisition with matching edible appearance at distance <=1.25 can select pickup despite unrelated ground/distant incompleteness. Body-result correspondence must hold. Only the acquisition_incomplete gate is bypassed; inventory, variation and life priorities are retained. Existing ordinary pickup choices use the same timed work. Packets are never rewritten to complete and learning keeps its existing full appearance-key requirements.

A started pickup reserves this individual's body for exactly500,000 virtual microseconds. World advances and other individuals continue acting. The busy individual still samples every250,000us, logging working_capture, but those records are not admitted as new Runtime decisions. On the exact completion boundary a capture is also logged without a new decision, preserving result.executed_us < next accepted capture. This is an explicit temporary decision-cadence change during work, not a dropped acquisition disguised as success.

Result-time World checks current stock, reach, line of sight and pose validity. Only picked_up changes stock/inventory. Simultaneous completions resolve by due time then agent ID; one remaining unit can yield one success and one not_found. Repeated starts do not duplicate work. Start requires enough authority time; near a day-phase boundary pickup becomes wait rather than starting work that would cross it. HarvestAgent expiry allows capture+500001us bounded by the next existing day phase. Other operations remain capture+1us.

After result admission normal observation/selection resumes. Learning does not automatically count incomplete observations just because the body acquired food.

## Actual lightweight result

Sparse seed20260928, three agents, approach field enabled, thirty days. Completed in20.874s. C completed12 pickups, each exactly0.5s after initiation. One patch depleted12→0; other seven remained12. Returns0, learning records0, adopted models0. There is no claim of learned behavior or successful return.

23,040 sensor captures. A/B each7,680 Runtime observations; C7,656 (24 busy/completion-boundary captures kept outside Runtime decisions). Complete work source IDs/results are preserved in `tests/fixtures/lightweight_timed_harvest30.jsonl.gz`; compact audit includes source/log hashes and duration checks.

The new `lw-timed-harvest-v1` event format separates decision/work_started/working_capture/completed. Existing LW replay viewer rejects this version rather than showing future completion as an immediate action. Viewer support is a follow-up; do not load this as lw-planar-world-v1.

Validation: four dedicated tests PASS (duration, competing stock, retry, pose/distance changes, deadline/partial start rejection, real Runtime pickup and strict learning), thirteen existing lightweight tests PASS. Full repository suite and Luanti not run.

Next: display the working phase, and separately consider the observation boundary required for learning successful local acquisition. No unrequested relaxation of learning or H connection is included.
