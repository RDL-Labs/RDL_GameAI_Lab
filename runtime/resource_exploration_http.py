"""Opt-in L14A transport; legacy endpoints and default runtime are unchanged."""
from .learned_exploration_http import LearnedExplorationHandler
from .exploration import RESOURCE_SCHEMA


class ResourceExplorationHandler(LearnedExplorationHandler):
    def do_GET(self):
        s = self.server.series
        with s.lock:
            if self.path == "/health":
                return self.send(200, dict(ok=True, schema=RESOURCE_SCHEMA, run_id=s.loop.run_id, periods=s.loop.periods))
            if self.path == "/v1/exploration-snapshot":
                return self.send(200, dict(exploration=s.loop.snapshot(), canonical=s.canonical.snapshot(), history={}))
        self.send(404, dict(error="unknown_endpoint"))
