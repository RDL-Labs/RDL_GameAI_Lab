# Local ground appearance and sampled pattern recognition

Code195d189. Reference integrations/lightweight/ground_appearance.py and
runtime/ground_pattern.py. Native option `--ground-perception on`, default off.

The same LW loop samples15 actor-relative points:five angles at distances1,2,4.
Existing physical obstacle footprints conservatively occlude ground. Visible
wear produces grass/trampled_grass/bare_ground. Water is not added because the
native sparse World has no landscape/water adapter yet.

Connected components use adjacent angle/distance sample indices, then covariance
major/minor axes classify a sampled band when at least3 samples and major>=4minor.
Output keeps sample links, unknown neighbors, extents and sampling-edge contact.
No unobserved connection, road destination or action authority is inferred.
Sources contain actor, observation identity and capture time; no World positions.
Native per-run state provides isolation; full transport packet binding is unported.

Pattern references use native observation+first sample identity rather than Python
SHA serialization. Structural sampled groups are compared against four frozen
Python reference cases:grass, band, partial occlusion, all unavailable.

The runner counts every observation/group and retains only the latest16 snapshots
per actor. It does not append every sensor sample to an unbounded log. Perception
alone does not modify candidate ranking. Ground continuity/body correspondence
and its candidate proposals remain the next integration step.

Initial run38348586242 passed structural/reference and living invariants, but
failed the observation-neutral exact output check. Independent comparison found
128 floating-point differences caused by subdividing lazy wear recovery according
to sampling frequency. No tolerance was widened:37d75de changes recovery to use
last-walk wear and absolute elapsed time, so reads cannot accumulate rounding.
A direct sparse-versus-frequent-read regression was added. Corrected run38348938603
passed36 assertions (safety16, reference/observation9, integrated8, neutrality3).


Three-day seed20261005,155520 operations per condition. All non-perception
result fields match exactly between enabled/disabled after the recovery fix.
Initial100+added95=ground60+stored129+consumed6; carried0. Stores A35/B59/C35.
Each actor produced51840 observations; only16 latest snapshots retained.
Worn-band group observations (trampled+bare):A21299,B30607,C21640.
These are repeated sampled groups, not distinct roads or independent discoveries.

Calls measured21.58s first/off and23.37s second/on; compilation/order differ, so
this is not a warmed performance comparison. Full long-run performance gate remains.
