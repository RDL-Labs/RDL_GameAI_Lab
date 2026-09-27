"""L11: bounded, opt-in fixture reaction; no canonical E/H or learning writes."""
from copy import deepcopy
from math import isfinite
from threading import RLock

SCHEMA = "l11-boundary-defense-v1"
LIMITATION = "fixture-instrumented-local-use-v1"
UNIT = 1_000_000
SCOPE = ("run_id", "world_epoch", "defender", "actor", "site_ref", "clock_id")


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def keys(value, expected):
    require(isinstance(value, dict) and set(value) == set(expected.split()), "invalid_fields")


def same(left, right):
    """Protocol identity includes JSON types (True must not alias integer 1)."""
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(same(left[k], right[k]) for k in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(same(a, b) for a, b in zip(left, right))
    return left == right


def label(value):
    return isinstance(value, str) and 0 < len(value) <= 160


def reaction_step(previous, elapsed_us, threshold):
    """All quantities integer micro-units; acquisition time determines decay."""
    require(all(integer(v) for v in (previous, elapsed_us, threshold)), "invalid_quantity")
    before = max(0, previous - elapsed_us)
    after = before + 4 * UNIT
    return {"previous_load": previous, "elapsed_us": elapsed_us,
            "decay": previous - before, "load_before": before,
            "appraisal_increment": 4 * UNIT, "load_after": after,
            "warning_threshold": threshold, "threshold_reached": after >= threshold}


class BoundaryDefense:
    """One frozen run. Stage validation before publishing; process-local only."""
    def __init__(self, run_id):
        require(label(run_id), "invalid_run")
        self.run_id = run_id
        self.lock = RLock()
        self._state = {"schema": SCHEMA, "config": None, "records": {}, "results": {},
                       "load": 0, "last_capture_us": None, "last_seq": 0, "permit": None}

    def snapshot(self):
        with self.lock:
            return deepcopy(self._state)

    def configure(self, config):
        with self.lock:
            keys(config, "schema run_id world_epoch defender actor site_ref clock_id registration profile reaction relation site_relation")
            require(config["schema"] == SCHEMA and config["run_id"] == self.run_id, "config_scope")
            require(integer(config["world_epoch"], 1), "invalid_epoch")
            require(all(label(config[k]) for k in SCOPE if k != "world_epoch"), "invalid_reference")
            require(len({config[k] for k in ("defender", "actor", "site_ref")}) == 3, "reference_alias")
            r = config["registration"]
            keys(r, "source unit_refs")
            require(label(r["source"]) and isinstance(r["unit_refs"], list) and 1 <= len(r["unit_refs"]) <= 8,
                    "invalid_registration")
            require(all(label(u) for u in r["unit_refs"]) and len(set(r["unit_refs"])) == len(r["unit_refs"]), "unit_alias")
            require(not set(r["unit_refs"]) & {config[k] for k in ("defender", "actor", "site_ref")}, "unit_alias")
            p = config["profile"]
            keys(p, "id revision radius")
            require(p["id"] in ("fixture-life-sensory", "fixture-life-sensory-compact") and integer(p["revision"], 1) and p["revision"] == 1,
                    "unsupported_profile")
            require(type(p["radius"]) is int and p["radius"] == 12, "profile_radius")
            reaction = config["reaction"]
            keys(reaction, "profile_id source base_threshold")
            require(label(reaction["profile_id"]) and label(reaction["source"]) and type(reaction["base_threshold"]) is int
                    and reaction["base_threshold"] in (3, 9), "invalid_reaction")
            keys(config["site_relation"], "source continued_use")
            require(label(config["site_relation"]["source"]) and config["site_relation"]["continued_use"] is True, "site_relation")
            if config["relation"] is not None:
                rel = config["relation"]
                keys(rel, "relation_id source action beneficiary_inclusion")
                require(label(rel["relation_id"]) and label(rel["source"]) and rel["action"] == "observed_unit_taken"
                        and type(rel["beneficiary_inclusion"]) is int and rel["beneficiary_inclusion"] in (0, 1), "invalid_relation")
            old = self._state["config"]
            require(old is None or same(old, config), "config_conflict")
            self._state = {**self._state, "config": deepcopy(config)}
            return {"configured": True, "run_id": self.run_id}

    def _sources(self, record, config, *, require_relation=True):
        """Validate the finite instrumented evidence, never query World truth."""
        keys(record, "notice before effect after")
        n = record["notice"]
        keys(n, "run_id world_epoch defender actor site_ref clock_id notice_id event_id unit_ref capture_us seq profile pose_ref before_id after_id action units coverage limitations")
        require(all(same(n[k], config[k]) for k in SCOPE), "notice_scope")
        require(all(label(n[k]) for k in ("notice_id", "event_id", "unit_ref", "pose_ref", "before_id", "after_id")), "invalid_reference")
        require(n["before_id"] != n["after_id"] and integer(n["capture_us"]) and integer(n["seq"], 1), "notice_order")
        require(same(n["profile"], config["profile"]) and n["limitations"] == LIMITATION, "notice_profile")
        require(n["action"] == "observed_unit_taken" and type(n["units"]) is int and n["units"] == 1, "invalid_action")
        require(n["coverage"] in ("complete", "partial"), "invalid_coverage")
        reasons = []
        if n["unit_ref"] not in config["registration"]["unit_refs"]:
            reasons.append("reference_unregistered")
        if require_relation and config["relation"] is None:
            reasons.append("relation_unconfigured")
        if n["coverage"] != "complete":
            reasons.append("acquisition_incomplete")
        for side, order in (("before", 1), ("after", 3)):
            p = record[side]
            if p is None:
                reasons.append("source_missing")
                continue
            keys(p, "packet_id observer capture_us seq order pose_ref profile coverage visible")
            require(p["packet_id"] == n[side + "_id"] and p["observer"] == n["defender"] and p["capture_us"] == n["capture_us"]
                    and p["seq"] == n["seq"] and p["order"] == order and p["pose_ref"] == n["pose_ref"]
                    and same(p["profile"], n["profile"])
                    and all(integer(p[k]) for k in ("capture_us", "seq", "order")), "packet_binding")
            require(p["coverage"] in ("complete", "partial"), "invalid_coverage")
            if p["coverage"] != "complete":
                reasons.append("acquisition_incomplete")
            require(isinstance(p["visible"], list) and len(p["visible"]) <= 2, "visible_budget")
            refs = set()
            for v in p["visible"]:
                keys(v, "ref kind distance relative_position")
                require(v["ref"] not in refs and v["ref"] in (n["actor"], n["unit_ref"]), "visible_reference")
                refs.add(v["ref"])
                require(v["kind"] == ("npc" if v["ref"] == n["actor"] else "food"), "visible_kind")
                xyz = v["relative_position"]
                keys(xyz, "x y z")
                values = list(xyz.values()) + [v["distance"]]
                require(all(type(x) in (int, float) and isfinite(x) for x in values), "invalid_distance")
                require(0 <= v["distance"] <= config["profile"]["radius"] and
                        abs(sum(x*x for x in xyz.values()) ** .5 - v["distance"]) <= .0001, "invalid_distance")
            if n["actor"] not in refs:
                reasons.append("actor_not_visible")
            if side == "before" and n["unit_ref"] not in refs:
                reasons.append("resource_not_visible")
            if side == "after" and n["unit_ref"] in refs:
                reasons.append("pickup_not_witnessed")
        effect = record["effect"]
        if effect is None:
            reasons.append("source_missing")
        else:
            keys(effect, "event_id actor site_ref unit_ref capture_us seq order action units established source")
            require(all(effect[k] == n[k] for k in ("event_id", "actor", "site_ref", "unit_ref", "capture_us", "seq", "action", "units"))
                    and all(integer(effect[k]) for k in ("capture_us", "seq", "order", "units"))
                    and effect["order"] == 2 and effect["source"] == LIMITATION, "effect_binding")
            require(type(effect["established"]) is bool, "invalid_effect")
            if not effect["established"]:
                reasons.append("pickup_not_established")
        return sorted(set(reasons))

    def observe(self, request):
        with self.lock:
            keys(request, "now_us record")
            require(integer(request["now_us"]), "invalid_now")
            s = self._state
            config = s["config"]
            require(config is not None, "unconfigured")
            record = request["record"]
            reasons = self._sources(record, config)
            n = record["notice"]
            require(request["now_us"] >= n["capture_us"], "future_capture")
            old = s["records"].get(n["notice_id"])
            if old:
                require(same(old["record"], record), "notice_conflict")
                return {"new_event": False, "receipt": deepcopy(old["receipt"])}
            require(len(s["records"]) < 8, "notice_capacity")
            for entry in s["records"].values():
                previous = entry["record"]["notice"]
                require(not any(n[k] == previous[k] for k in ("event_id", "unit_ref", "before_id", "after_id", "seq")), "source_alias")
                require(not {n["before_id"], n["after_id"]} & {previous["before_id"], previous["after_id"]}, "source_alias")
            require(request["now_us"] <= n["capture_us"] + 500_000, "admission_expired")
            require(n["seq"] > s["last_seq"] and (s["last_capture_us"] is None or n["capture_us"] >= s["last_capture_us"]), "capture_reversed")
            receipt = {"notice_id": n["notice_id"], "status": "unavailable" if reasons else "evaluated",
                       "reasons": reasons, "evaluation": None, "permit": None}
            staged = deepcopy(s)
            if not reasons:
                # Unavailable observations do not advance the load's reference time.
                accepted = [v["record"]["notice"]["capture_us"] for v in s["records"].values() if v["receipt"]["status"] == "evaluated"]
                elapsed = n["capture_us"] - max(accepted) if accepted else 0
                threshold = UNIT * (config["reaction"]["base_threshold"] + 8 * config["relation"]["beneficiary_inclusion"])
                evaluation = reaction_step(s["load"], elapsed, threshold)
                evaluation.update(relation=deepcopy(config["relation"]), reaction=deepcopy(config["reaction"]),
                                  registration_source=config["registration"]["source"], site_relation=deepcopy(config["site_relation"]))
                receipt["evaluation"] = evaluation
                staged["load"] = evaluation["load_after"]
                if evaluation["threshold_reached"] and s["permit"] is None:
                    permit = {k: config[k] for k in SCOPE}
                    permit.update(operation_id=n["notice_id"] + ":warning", notice_id=n["notice_id"],
                                  capture_us=n["capture_us"], expires_us=n["capture_us"] + UNIT, duration_us=250_000)
                    receipt["permit"] = permit
                    staged["permit"] = deepcopy(permit)
            staged["last_capture_us"] = n["capture_us"]
            staged["last_seq"] = n["seq"]
            staged["records"][n["notice_id"]] = {"record": deepcopy(record), "receipt": deepcopy(receipt)}
            self._state = staged
            return {"new_event": True, "receipt": deepcopy(receipt)}

    def result(self, request):
        with self.lock:
            response = validate_display_receipt(request, self._state["permit"], self._state["results"])
            self._state = {**self._state, "results": {**self._state["results"], response["operation_id"]: deepcopy(request)}}
            return response


def validate_display_receipt(request, permit, results):
    """Pure, shared L11/L12 display receipt checks."""
    keys(request, "permit status started_us ended_us readback cleared")
    require(permit is not None and same(request["permit"], permit), "result_binding")
    p = permit
    require(integer(request["started_us"]) and integer(request["ended_us"]), "invalid_result_time")
    if request["status"] == "displayed":
        require(p["capture_us"] <= request["started_us"] <= p["expires_us"] and
                request["ended_us"] >= request["started_us"] + p["duration_us"] and
                request["readback"] == "WARNING" and request["cleared"] == "", "display_evidence")
    else:
        require(request["status"] == "action_expired" and request["started_us"] > p["expires_us"] and
                request["ended_us"] == request["started_us"] and request["readback"] == "" and request["cleared"] == "", "expiry_evidence")
    key = p["operation_id"]
    old = results.get(key)
    require(old is None or same(old, request), "result_conflict")
    return {"operation_id": key, "new_result": old is None}
