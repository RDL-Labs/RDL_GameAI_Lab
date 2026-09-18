# ρ v0.x Operational Reference Evidence

**Status:** Closed operational reference; further expansion deferred

**Evidence date:** 2026-09-18

## Established boundary

ρ v0.x is sufficient as a reusable GameAI observation tool. The completed
evidence chain is:

```text
same World
→ domain-specific finite rho profile
→ LOW / MID / HIGH bounded projection
→ versioned packet sidecar + provenance
→ candidate-description difference
→ unchanged selector
→ different chosen target
→ unchanged Trajectory ownership
```

The following completion conditions are met:

1. Domain-specific profiles exist for Food and Rest.
2. LOW / MID / HIGH levels and projection-rule versions are finite.
3. `observation_resolution` is an opt-in packet sidecar.
4. Selection and projection provenance are retained.
5. Food proves projection and packet non-intervention.
6. Rest proves cross-domain reuse.
7. Rest proves `ρ → candidate description → fixed selector → target difference`.
8. Canonical `M_B`, H, T1, salience, Need, and Trajectory persistence remain
   outside ρ authority.

The live controlled result is:

```text
LOW  → candidate safety difference masked → z_grove
HIGH → safe / uncertain retained         → plaza
```

This does not establish HIGH as smarter or better. It establishes only that a
finite observation distinction can causally alter a downstream choice while
selection and persistence rules stay fixed.

## Deferred expansion

The following are not current implementation priorities:

- dynamic or learned ρ;
- DNA / Neural-derived ρ;
- Threat, Novelty, Space, or Time expansion for its own sake;
- automatic domain proliferation;
- canonical admission or H/T1 coupling.

Future game features may reuse ρ when they have a concrete distinction question.
They must not be created merely to expand the ρ subsystem.

## Reopen criteria

Reopen ρ development only when a game feature requires a named bounded
distinction that cannot be tested with the current profile, sidecar, provenance,
and candidate-description contracts. Any reopening requires a domain-specific
Acceptance and must preserve the authority separations above.
