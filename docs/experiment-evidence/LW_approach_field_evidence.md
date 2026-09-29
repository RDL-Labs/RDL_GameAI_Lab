# LW purpose-conditioned approach field

Baseline cd5b9f3. Explicit `--approach-mode enabled` selects a lightweight-only CampaignAgent subclass. Default disabled retains ReturnCampaign. Existing Runtime selection rules, learning, collision and physical exclusions remain unchanged.

When existing priority gates admit visible-food locomotion and current terrain/Food acquisition is complete, the optional projection scales scored directions' soft obstacle cost by 0.1. Physical exclusions and physical/food/model-field contributions remain. This coefficient is a fixed initial experimental setting, not a learned parameter or biological constant. Original obstacle values/source contributions and current observation/target refs are retained. The field is recalculated from each observation; no target means no application. It does not override night, return, missing-data, pickup or body authority gates. It does not infer a path around actual obstacles, grant passage through them, or mutate M_B. H is not used.

This implements the local switch in what the movement field values when food is observed; it is not a general goal architecture or a guarantee that an approach will succeed. All currently eligible frontal matching food remains in the existing finite appraisal set.

## Sparse thirty-day result

Seed20260928, 3 agents, rays sensor, sparse layout, model field enabled. 30 days completed in20.202s, 7,680 observations each, harvest0/returns0/models0. The approach projection applied13 times to C.

Compared with saved approach-disabled sparse run, C's closest observed food distance changed from3.837 to0.843 (pickup reach1.25). At6.5s C turned45 degrees; at6.75s it moved toward the now-frontal food rather than requesting the old additional90-degree turn. It continued until7.5s, when it was within reach.

At7.5s ground coverage became partial while Food and distant were complete. Existing observation_key rejected the combined observation before pickup selection and returned acquisition_incomplete. Thus approach now reaches the food, but acquisition still does not occur. This is not a failed pickup World operation. C total movement22 rather than138; reduced distance is not claimed as improved foraging efficiency because harvest remains0.

Artifacts: tests/fixtures/lightweight_approach30.jsonl.gz and lightweight_approach30_audit.json. New optional approach_field trace records purpose, source and applied scale. Existing viewer can load the gzip; detailed projection is in the log.

Validation: four pure projection tests PASS (input isolation, soft-only change, hard exclusion, missing target/incomplete coverage, preserved model cost), thirteen lightweight tests PASS. Full suite and Luanti not run. Next distinct contract: allow a sourced reachable pickup to rely on appropriate Food/body evidence without treating unrelated ground incompleteness as complete; preserve the stricter conditions required by learning. No such pickup change is included here.
