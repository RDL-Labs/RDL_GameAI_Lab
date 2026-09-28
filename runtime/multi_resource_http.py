"""Explicit L14B transport; finite agent registry, existing endpoints unchanged."""
from .learned_exploration_http import LearnedExplorationHandler
from .multi_resource_exploration import SCHEMA


class MultiResourceHandler(LearnedExplorationHandler):
    def do_GET(self):
        s = self.server.series
        with s.lock:
            if self.path == "/health":
                return self.send(200, dict(ok=True, schema=s.loop.schema, run_id=s.loop.run_id, periods=s.loop.periods))
            if self.path == "/v1/exploration-snapshot":
                return self.send(200, dict(exploration=s.loop.snapshot(), history={}))
        self.send(404, dict(error="unknown_endpoint"))
