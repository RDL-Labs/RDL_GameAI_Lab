# Food-Safety Continuous-Life Contract

**Status:** Phase E operational reference

## Integrated Chain

`FoodSafetyCoordinator` is the only Phase E authority allowed to receive a
packet with both Food and Safety action modes explicitly enabled:

```text
Food trajectory + held food + return to Base
-> bounded danger appears
-> FOOD_SUSPENDED
-> Safety target selected once
-> flee until committed safe target
-> Safety COMPLETE
-> current Food relations re-evaluated
-> RESUME or RELEASE
-> valid held-food/Base relation resumes deposit
```

The coordinator delegates Food semantics to `BaseFoodLifePolicy` and Safety
semantics to `SafetyTrajectoryPolicy`. It does not alter either selector. An
explicit `food_safety_integration_enabled` body field is required; merely
setting both legacy flags remains invalid.

## Resume Boundary

Safety completion does not restore an old action blindly. The Food policy sees
the current bounded packet again. If its retained trajectory and current held
food/Base/visibility relations remain valid, the coordinator reports `RESUME`.
If the Food policy structurally releases, it reports `RELEASE`.

The live evidence activates a Godot-owned danger zone after pickup. The same
NPC suspends Food and flees to East Shelter, which is distinct from Plaza/Base.
After Safety completion it rechecks the held-food/Base relation, resumes with
`approach(plaza)`, travels back, deposits, and admits the ordinary causally
bound success result. This proves resume is not an artifact of safe target and
Base sharing one location.

This is one named Food/Safety coordination rule, not a general Need arbitration
engine. Rest, Energy, injury, H, canonical authority, and rho changes remain
outside the contract.
