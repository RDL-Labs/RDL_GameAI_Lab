# Shared camp storage and periodic resource floor

Source3bc7555; reference social_life.py and resource_regrowth.py.
--stores personal (default) retains the existing native private stores; shared
uses one World-owned stock. Only at-home decisions can retrieve it, and execution
checks local reach again. Deposit transfers carried food into it, retrieve moves
one unit out; sequential execution resolves simultaneous demand without creating
food. Shared and initial private stores cannot be combined implicitly.

The food ledger includes shared stock exactly once. Agent private stocks remain
zero in shared mode. Shared inventory and configuration survive environmental
cohort transfer; previous agent-held food is not transferred with it. Cargo
source handling remains the existing accepted-deposit/unknown-stock-source model.
No automatic ownership relation or negotiation feature is added.

--regrowth-days N controls the global World-day period. --regrowth-capacity K
sets the minimum replenished resource stock, never subtracting excess stock.
The default capacity0 preserves each original resource's native cap; positive
capacity12 matches the Python reference setting. Original resource sites only
are replenished; dropped objects are not. World offset determines the phase
across cohort boundaries and incompatible settings are rejected.

Actions38369218616 pending: private/shared four-day comparison with a three-day
period, A-deposit/B-or-C-retrieve fixture, conservation, exact replay and shared
stock cohort transfer. No acceptance claim before completion.
