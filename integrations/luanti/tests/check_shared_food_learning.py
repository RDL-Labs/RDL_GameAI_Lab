"""Validate real shared-resource effects independently of the L10C controller."""
import json
from copy import deepcopy
from pathlib import Path
import sys

from runtime.sensory_food_learning import SHARED_CONTEXT

VARIANTS = {"both_active": (True, True), "neither_active": (False, False),
            "a_only": (True, False), "b_only": (False, True), "reversed_cues": (True, True)}
TOTALS = {"both_active": ((10, 6), (10, 6)), "neither_active": ((12, 6), (12, 6)),
          "a_only": ((10, 5), (12, 7)), "b_only": ((12, 7), (10, 5)),
          "reversed_cues": ((10, 6), (10, 6))}
AGENTS = ("npc_a", "npc_b")


def check(data):
    w, l, s, c = (data[k] for k in ("world", "learning", "sensory", "canonical"))
    assert "failure" not in w, w.get("failure")
    assert w["schema"] == "l10c-world-v1" and l["schema"] == "luanti-sensory-learning-l10c-v1"
    assert l["context"] == SHARED_CONTEXT and w["resets"] == len(w["episodes"]) == 12
    assert w["lua_checks"] >= 60
    scenario = w["scenario"]
    active = dict(zip(AGENTS, VARIANTS[scenario]))
    assert s["count"] == 72 and s["rejection_count"] == 0
    frames = {f["frame_id"]: f for f in s["frames"]}
    assert len(frames) == 72
    counts = {a: [0, 0] for a in AGENTS}
    experiences, models, delivery_first = set(), {}, set()
    for ep in w["episodes"]:
        index = ep["index"]
        assert ep["episode_id"] == w["run_id"] + f":shared-episode:{index}"
        assert 0 <= ep["ready_us"] - ep["capture_us"] <= 500000
        t = ep["trial"]
        assert t["complete"] and not t.get("aborted") and t["claims"] == ep["entity_removals"] == 1
        assert len(ep["decision_deliveries"]) == 4
        delivery_first.add(ep["decision_deliveries"][0]["agent_id"])
        trained_first = "npc_a" if (ep["color_band"] == "muted_red") != (scenario == "reversed_cues") else "npc_b"
        actual_first = trained_first if index <= 10 else AGENTS[1 - AGENTS.index(trained_first)]
        assert ep["first_agent"] == actual_first
        attempts = []
        for agent in AGENTS:
            a = t["actors"][agent]
            record = ep["by_agent"][agent]
            req = record["request"]
            ledger = l["by_agent"][agent]
            op = ledger["operations"][req["operation_id"]]
            decision = op["decision"]
            receipt = ledger["results"][req["operation_id"]]
            result = receipt["result"]
            assert op["request"] == req and req["episode_id"] == ep["episode_id"]
            assert json.loads(record["decision_wire"]) == decision
            # Luanti's JSON parser drops null-valued object fields and writes empty tables as null.
            body_decision = deepcopy(a["decision"])
            body_decision["prediction"].setdefault("values", None)
            for key in ("reasons", "source_candidates"):
                body_decision["prediction"][key] = body_decision["prediction"].get(key) or []
            assert decision == body_decision and decision["agent_id"] == agent
            assert result["decision_id"] == decision["decision_id"]
            f = frames[decision["frame_id"]]
            assert f["agent_id"] == agent and f["capture_window"]["end_us"] == ep["capture_us"]
            assert f["payload"]["features"][0]["color_band"] == ep["color_band"]
            assert set(op["section"]) <= {"purpose", "context", "run_id", "world_epoch", "agent_id", "section_id",
                "frame_id", "capture_window", "observer_frame_ref", "clock_id", "profile_id", "profile_revision",
                "sensor_model_revision", "sampled_world_tick", "feature", "reasons", "phase", "outcome"}
            assert op["section"]["context"] == SHARED_CONTEXT
            is_known = index > 8 and active[agent]
            expected_attempt = not is_known or agent == trained_first
            assert decision["action"] == ("attempt_food" if expected_attempt else "defer")
            assert decision["prediction"]["status"] == ("known" if is_known else "unknown")
            assert bool(decision["prediction"]["source_candidates"]) == is_known
            if is_known:
                assert decision["prediction"]["values"] == {"food_acquired": float(agent == trained_first)}
            models.setdefault((agent, index > 8), set()).add(decision["model_ref"])
            assert a["authority_consumptions"] == 1 and a["attempted"] == result["attempted"] == expected_attempt
            assert record["foreign_rejected"] and record["replay_rejected"]
            assert a["release_us"] == t["start_us"] + (0 if agent == actual_first else 250000)
            assert a["release_us"] <= a["started_us"] < a["release_us"] + 250000
            assert a["started_us"] <= decision["expires_us"]
            assert req["now_us"] <= result["completed_us"] <= req["now_us"] + 5000000
            assert result["completed_us"] == a["completed_us"]
            stock_delta = record["base_stock_after"] - record["base_stock_before"]
            assert stock_delta == int(a["deposited"]) == int(a["acquired"])
            counts[agent][0] += int(expected_attempt)
            counts[agent][1] += stock_delta
            trace = a["trace"] or []
            assert len(trace) == a["actions"] <= 16
            assert len({v["slot"] for v in trace}) == len(trace)
            for v in trace:
                assert t["start_us"] + v["slot"] * 250000 <= v["at_us"] < t["start_us"] + (v["slot"] + 1) * 250000
                assert abs(v["after_x"] - v["before_x"]) <= 1
                if v["kind"] == "pickup_attempt": assert abs(v["before_x"]) <= 1.25
                if v["kind"] == "deposit": assert abs(v["before_x"] - record["start_x"]) <= 1.25
            if expected_attempt:
                attempts.append(agent)
                assert len([v for v in trace if v["kind"] == "pickup_attempt"]) == 1
                assert a["actions"] == (7 if a["acquired"] else 4)
                assert result["food_acquired"] == a["acquired"]
                exp = receipt["experience"]
                assert exp["agent_id"] == agent and exp["episode_id"] == ep["episode_id"]
                assert exp["record_id"] not in experiences
                experiences.add(exp["record_id"])
                assert receipt["F_prime"]["model_ref"] == decision["model_ref"]
                if is_known:
                    assert receipt["comparison"]["E"]["deltas"] == {"food_acquired": float(a["acquired"]) - 1.0}
                else: assert receipt["comparison"]["status"] == "not_comparable"
            else:
                assert result["food_acquired"] is None and receipt["experience"] is None
                assert receipt["comparison"]["status"] == "not_attempted"
                assert not trace and record["start_x"] == record["finish_x"]
        winner = actual_first if actual_first in attempts else attempts[0]
        assert t["claimant"] == ep["claimant"] == winner
        assert sum(t["actors"][a]["acquired"] for a in AGENTS) == 1
        for agent in AGENTS:
            # Resource disappeared globally even when this particular agent deferred or lost.
            assert len(ep["packets"]["before"][agent]["observation"]["visible_objects"]) == 1
            assert ep["packets"]["after"][agent]["observation"]["visible_objects"] == []
    assert delivery_first == set(AGENTS), "exercise both response delivery orders"
    for i, agent in enumerate(AGENTS):
        assert tuple(counts[agent]) == TOTALS[scenario][i]
        own = l["by_agent"][agent]
        assert len(own["operations"]) == len(own["results"]) == 12 and len(own["learning"]) == 1
        learned = next(iter(own["learning"].values()))["response"]
        assert (learned["status"] == "activated") == active[agent]
        own_exps = {r["experience"]["record_id"] for r in own["results"].values() if r["experience"]}
        for candidate in learned["candidates"]:
            sig = candidate["common_relation_signature"]
            assert candidate["agent_id"] == sig["boundary"]["agent_id"] == agent
            assert sig["boundary"]["context"] == SHARED_CONTEXT and candidate["support_count"] == 3
            formed, validated = set(sig["formation_experiences"]), set(sig["validation_experiences"])
            assert len(formed) == 3 and len(validated) == 1 and not formed & validated
            assert formed | validated <= own_exps
        assert len(models[agent, False]) == len(models[agent, True]) == 1
        assert (models[agent, False] != models[agent, True]) == active[agent]
    assert c["model_cutover"]["count"] == len(c["model_archive"]) == sum(active.values())
    assert c["M_delta"]["active_count"] == 2 - sum(active.values())
    return {"scenario": scenario, "shared_episodes": 12, "frames": 72,
            "attempts_deposits": counts, "lua_checks": w["lua_checks"]}


if __name__ == "__main__":
    print("L10C PASS", json.dumps(check(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig")))))
