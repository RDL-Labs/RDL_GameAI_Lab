"""Finite continuous days: observed skyline homing and local night record review.

Initial landmark servo, not learned routing. No World coordinates or reverse tape.
Night wait/review is not canonical SleepConsolidation/T1 authority.
"""
from copy import deepcopy
from math import sqrt
from .exploration import fields, require, number, ref
from .landmark_exploration import initial_state
from .neighborhood_exploration import local_state
from .terrain_steering import SteeredResourceAgent, SteeredResourceExploration

SCHEMA = "l15a-landmark-day-cycle-v1"
from .lw_time import DAY_US, BOUNDARIES


def phase(capture):
    t = capture % DAY_US
    return next(name for end, name in zip(BOUNDARIES, ("orientation", "exploration", "return", "night")) if t < end)


def validate_skyline(p):
    f = p["skyline"]
    fields(f, "model source coverage features")
    require(f["model"] == "finite-elevated-fan-v1", "skyline_model")
    require(f["source"] == {k:p[k] for k in ("agent_id", "observation_id", "capture_us", "pose_ref")}, "skyline_binding")
    require(f["coverage"] in ("complete", "partial"), "skyline_coverage")
    require(isinstance(f["features"], list) and len(f["features"]) <= 39, "skyline_budget")
    seen = set()
    for x in f["features"]:
        fields(x, "ref color azimuth elevation range_band")
        ref(x["ref"]); require(x["ref"] not in seen, "skyline_reference"); seen.add(x["ref"])
        require(x["color"] in ("green", "brown", "gray", "blue", "red", "ochre"), "skyline_color")
        require(x["elevation"] in (0,15,30), "skyline_elevation")
        require(x["range_band"] in ("near", "mid", "far"), "skyline_range")
        require(isinstance(x["azimuth"], list) and len(x["azimuth"]) == 2, "skyline_angle")
        for n in x["azimuth"]: number(n,-90,90)
        require(x["azimuth"][0] < x["azimuth"][1], "skyline_interval")


def clusters(features):
    # Adjacent rays can describe a single angular patch; this is not object identity.
    intervals = sorted(x["azimuth"] for x in features)
    out = []
    for lo,hi in intervals:
        if out and lo <= out[-1][1]: out[-1][1] = max(hi,out[-1][1])
        else: out.append([lo,hi])
    return out


def home_review(packet, memory, state, linked, result, *, continuous=False):
    s = deepcopy(state)
    if continuous and s["outcome"] not in (None,"home_like_observed"):s["outcome"]=None
    if s["outcome"] is not None: return ["wait",0], s
    if not linked: s["outcome"] = "body_correspondence_unavailable"
    elif result and result["status"] == "blocked": s["outcome"] = "blocked"
    elif memory is None: s["outcome"] = "home_appearance_unavailable"
    if s["outcome"] is not None: return ["wait",0], s
    f = packet["skyline"]
    if f["coverage"] != "complete":
        s["diagnostic"] = "acquisition_incomplete"
        if not continuous and s["scans"] >= 4: s["outcome"] = "acquisition_incomplete"; return ["wait",0], s
        s["scans"] += 1
        return ["turn",90], s
    found = [x for x in f["features"] if x["color"] == memory["color"]]
    patches = clusters(found)
    s["candidates"] = patches
    if len(patches) != 1:
        s["diagnostic"] = "ambiguous" if patches else "not_observed"
        if not continuous and s["scans"] >= 4: s["outcome"] = s["diagnostic"]; return ["wait",0], s
        s["scans"] += 1
        return ["turn",90], s
    s["diagnostic"] = "appearance_candidate"
    # Near is a coarse observation, not proof of returning to the exact start.
    if any(x["range_band"] == "near" for x in found):
        s["outcome"] = "home_like_observed"; return ["wait",0], s
    if not continuous and s["operations"] >= 64: s["outcome"] = "operation_budget"; return ["wait",0], s
    angle = sum(patches[0])/2
    s["operations"] += 1
    if abs(angle) > 7.5:
        return ["turn",max(-45,min(45,round(angle/5)*5))], s
    return ["move",1], s


class DayCycleAgent(SteeredResourceAgent):
    period_us = DAY_US

    def expiry(self, capture_us):
        start = capture_us//DAY_US*DAY_US
        boundary = next(start+b for b in BOUNDARIES if start+b > capture_us)
        return min(super().expiry(capture_us), boundary)

    def _packet(self,p):
        require(isinstance(p,dict) and "skyline" in p, "skyline_required")
        super()._packet({k:v for k,v in p.items() if k != "skyline"})
        validate_skyline(p)

    def _stage_day_state(self, old):
        return deepcopy(old)

    def _return_review(self,p,memory,state,linked,result):
        return home_review(p,memory,state,linked,result,continuous=getattr(self,"continuous_selection",False))

    def _activity_phase(self,p,state,old):
        return phase(p['capture_us'])

    def _decision(self,p):
        day, mode = p["capture_us"]//DAY_US, phase(p["capture_us"])
        last = next(reversed(self.decisions.values())) if self.decisions else None
        old = last.get("day_cycle") if last else None
        s = self._stage_day_state(old) if old else dict(day=day, phase=mode, home_memory=None,
            return_state=None, nights=[], fatigue=0., charged_operation=None, night_wait_us=0)
        previous = next(reversed(self.observations.values())) if self.observations else None
        r = self.results.get("op:"+previous["observation_id"]) if previous else None
        linked = previous is None or (r is not None and r["after_pose_ref"] == p["pose_ref"]
            and r["after_revision"] == p["body_revision"] and r["executed_us"] < p["capture_us"])
        if r is not None and s["charged_operation"] != r["operation_id"]:
            s["fatigue"] = min(12.,s["fatigue"]+sqrt(r["forward"]**2+r["right"]**2+r["up"]**2)+abs(r["yaw"])/360)
            s["charged_operation"] = r["operation_id"]
            if linked and r["status"] == "waited":
                duration = min(250000,p["capture_us"]-r["executed_us"])
                s["fatigue"] = max(0.,s["fatigue"]-2*duration/1000000)
                if old and old["phase"] == "night": s["night_wait_us"] += duration
        if old is None:
            candidates = {x["color"] for x in p["skyline"]["features"] if x["range_band"] == "near" and x["elevation"] >= 15}
            if p["skyline"]["coverage"] == "complete" and len(candidates) == 1:
                s["home_memory"] = dict(color=next(iter(candidates)), source=p["observation_id"],
                    capture_us=p["capture_us"], pose_ref=p["pose_ref"], observation=deepcopy(p["skyline"]))
        if old is None or old["day"] != day:
            s["return_state"] = dict(scans=0,operations=0,outcome=None,diagnostic=None,candidates=[])
        mode = self._activity_phase(p,s,old)
        if mode == "exploration":
            d = super()._decision(p)
        else:
            model = self._prospective[1]
            d = dict(period=day, action=["wait",0],target="",reason="day_"+mode,
                landmark=initial_state(),neighborhood=local_state(),approach=None,blocked_targets=[],
                movement_terrain=None,terrain_gate="day_phase",harvest_prediction=None,
                model_ref=model.model_ref if model else None,exploration_started=False,
                authority="initial observed homing and finite night review; no new model authority")
            if mode == "return":
                d["action"],s["return_state"] = self._return_review(p,s["home_memory"],s["return_state"],linked,r if old and old["phase"] == "return" else None)
                d["reason"] = "return_"+(s["return_state"]["outcome"] or s["return_state"]["diagnostic"])
            if mode == "night" and (old is None or old["phase"] != "night"):
                if s["return_state"]["outcome"] is None: s["return_state"]["outcome"] = "deadline"
                records = []
                eligible = [o for o in self.observations.values() if o["capture_us"]//DAY_US == day
                    and self.commands[o["observation_id"]]["kind"] != "wait"
                    and "op:"+o["observation_id"] in self.results]
                for o in eligible[-16:]:
                    result = self.results.get("op:"+o["observation_id"])
                    if result is not None:
                        records.append(dict(observation=o["observation_id"],operation=result["operation_id"],
                            status=result["status"],capture_us=o["capture_us"],executed_us=result["executed_us"]))
                s["nights"].append(dict(day=day,source=p["observation_id"],records=records,
                    return_outcome=s["return_state"]["outcome"],status="local_records_reviewed",
                    canonical_sleep="not_connected",admission="none"))
        s.update(day=day,phase=mode)
        d["day_cycle"] = s
        return d


class DayCycleExploration(SteeredResourceExploration):
    schema = SCHEMA
    agent_type = DayCycleAgent

    def __init__(self,run_id,periods=3,seed=20260928,assignment="steady"):
        require(type(periods) is int and 1 <= periods <= 3,"day_budget")
        super().__init__(run_id,periods,seed,assignment)

    def snapshot(self):
        s=super().snapshot();s["period_us"]=DAY_US
        return s
