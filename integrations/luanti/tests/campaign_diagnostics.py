"""Bounded host-side timings; never used by agent decisions."""
from collections import deque
from copy import deepcopy
from threading import Lock
from time import perf_counter_ns


class TimedLoop:
    def __init__(self, loop):
        self.loop = loop
        self.stats = {}
        self.slow = deque(maxlen=128)
        self.lock = Lock()

    def __getattr__(self, name):
        value = getattr(self.loop, name)
        if name not in ("configure", "observe", "result", "finish"):
            return value
        def measured(packet):
            start = perf_counter_ns()
            try:
                return value(packet)
            finally:
                us = (perf_counter_ns() - start) // 1000
                capture = packet.get("capture_us", packet.get("executed_us", packet.get("ended_us", 0)))
                day = min(32, max(1, capture // 64000000 + 1))
                with self.lock:
                    key = f"{day}:{name}"
                    stat = self.stats.setdefault(key, dict(count=0, total_us=0, max_us=0))
                    stat["count"] += 1
                    stat["total_us"] += us
                    stat["max_us"] = max(stat["max_us"], us)
                    if us >= 100000:
                        self.slow.append(dict(kind=name, agent_id=packet.get("agent_id"), capture_us=capture, elapsed_us=us))
        return measured

    def diagnostics(self):
        with self.lock:
            return dict(schema="campaign-runtime-timing-v1", stats=deepcopy(self.stats), slow=list(self.slow),
                        scope="loop calls inside existing HTTP lock; excludes lock wait, JSON and network")
