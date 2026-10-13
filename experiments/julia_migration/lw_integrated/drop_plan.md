# Julia LW dropped cargo: implementation awaiting execution

Baseline: `b9d3a921`; implementation: `02318d3` plus this documentation.
Status: IMPLEMENTED LOCALLY / CLOUD ACCEPTANCE NOT RUN.

The existing native entry accepts `--dropping on` (default off). With climbing
also enabled, a visible target and a locally observed low obstacle can produce
a one-unit drop candidate when reducing load by one makes climbing feasible.
This is a fixed means-selection rule, not a learned plan or general emergency
cargo policy. Existing priority and method selection remain in control.

Dropped food becomes a visible loose-food object in the same World. Recovery
uses current distance and collision checks, and any individual may recover it.
Original acquisition provenance follows the unit; recovery does not create a
new harvest-learning trial. It can satisfy the immediate food-acquisition goal.
Drop only satisfies load reduction, never return or food acquisition by itself.

The ledger includes ground cargo. Dawn renewal touches original resource sites
only. At most 256 ground-cargo slots are allocated; empty slots may be reused
on a later tick. They cannot change identity within the shared observation tick.
At capacity, drop is explicitly rejected without deleting cargo. Transfer records
retain the latest 32 entries, with aggregate counters. One last operation receipt
per individual protects duplicate same-tick transfers; this is not persistent
network delivery deduplication. Drop/recovery uses the existing rest-like body
cost for an operation, not a new lifting physiology model.

The dedicated `julia-lw-drop.yml` workflow contains transfer/provenance and
load/method tests, the existing safety tests, a native three-day off/on comparison,
and a controlled one-day case through the same living loop. It has NOT run yet:
automatic approval review rejected the direct push to main. Julia is unavailable
locally. No PASS, actual drop count, or performance claim is made.

Observe drop/recovery cycles rather than suppressing them with a hidden ban.
No safety drop, property permission, ground-cargo decay, or general cargo planning
is included. Local inventory invariants and whole-World food conservation remain
asserted at each operation. Follow-up acceptance must inspect actual transfers,
final ledger, Sleep and prior off-mode results before declaring completion.
