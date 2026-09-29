"""Bounded host-side timings; never used by agent decisions."""
import gc
from collections import deque
from copy import deepcopy
from threading import Lock
from time import perf_counter_ns


class TimedLoop:
    def __init__(self, loop, track_gc=False):
        self.loop = loop
        self.stats = {}
        self.slow = deque(maxlen=128)
        self.lock = Lock()
        self.current = None
        self.gc_stats = {}
        self.gc_slow = deque(maxlen=128)
        self.gc_start = {}
        self.track_gc = track_gc
        if track_gc: gc.callbacks.append(self.collection)

    def collection(self, phase, info):
        generation = info["generation"]
        if phase == "start":
            self.gc_start[generation] = perf_counter_ns()
        elif generation in self.gc_start:
            us = (perf_counter_ns() - self.gc_start.pop(generation)) // 1000
            stat = self.gc_stats.setdefault(str(generation), dict(count=0, total_us=0, max_us=0))
            stat["count"] += 1; stat["total_us"] += us; stat["max_us"] = max(stat["max_us"], us)
            if self.current is not None: self.current["gc_us"] += us
            if us >= 100000:
                self.gc_slow.append(dict(generation=generation, elapsed_us=us,
                    call=dict(self.current) if self.current is not None else None))

    def close(self):
        if self.track_gc:
            gc.callbacks.remove(self.collection)
            self.track_gc = False

    def __getattr__(self, name):
        value = getattr(self.loop, name)
        if name not in ("configure", "observe", "result", "finish"):
            return value
        def measured(packet):
            start = perf_counter_ns()
            metadata = packet if isinstance(packet, dict) else {}
            capture = metadata.get("capture_us", metadata.get("executed_us", metadata.get("ended_us", 0)))
            if type(capture) is not int: capture = 0
            self.current = dict(kind=name, agent_id=metadata.get("agent_id"), capture_us=capture, gc_us=0)
            try:
                return value(packet)
            finally:
                us = (perf_counter_ns() - start) // 1000
                current = self.current; self.current = None
                day = min(32, max(1, capture // 64000000 + 1))
                with self.lock:
                    key = f"{day}:{name}"
                    stat = self.stats.setdefault(key, dict(count=0, total_us=0, max_us=0))
                    stat["count"] += 1
                    stat["total_us"] += us
                    stat["max_us"] = max(stat["max_us"], us)
                    if us >= 100000:
                        self.slow.append(dict(current, elapsed_us=us))
        return measured

    def diagnostics(self):
        with self.lock:
            return dict(schema="campaign-runtime-timing-v2", stats=deepcopy(self.stats), slow=deepcopy(list(self.slow)),
                        gc=dict(enabled=self.track_gc, stats=deepcopy(dict(self.gc_stats)), slow=deepcopy(list(self.gc_slow))),
                        scope="loop calls inside existing HTTP lock; excludes lock wait, JSON and network")
