"""L15A: bounded, reproducible near-minimum perturbation; no steering memory.

Episode state lives only in accepted decisions. Computing a proposed decision
does not consume a seed or mutate a counter before observation admission.
"""
from copy import deepcopy

from .exploration import fields, require, integer, ref
from .exploration_series import digest
from .resource_exploration import PERIOD_US
from .subjective_movement_terrain import calculate_terrain, DIRECTIONS, TIE_TOLERANCE
from .terrain_resource_exploration import TerrainResourceAgent, TerrainResourceExploration, terrain_input, terrain_action

SCHEMA = "l15a-terrain-tie-break-v1"
SAMPLER = "sha256-ranked-near-minimum-v1"
MODES = ("disabled", "frozen")
NEAR_WIDTH = .10
MAX_HEIGHT = .05
MAX_DECISIONS = 3
LIFETIME_US = 750000


def near_minimum(terrain):
    if terrain["status"] != "complete":
        return [], "terrain_" + terrain["status"]
    rows = [r for r in terrain["directional_samples"] if r["status"] == "scored"
            and r["total"] <= terrain["minimum_height"] + NEAR_WIDTH + TIE_TOLERANCE]
    if len(rows) < 2:
        return [], "no_near_tie"
    if any(max(r[k] for r in rows) - min(r[k] for r in rows) > NEAR_WIDTH + TIE_TOLERANCE
           for k in ("physical", "food", "obstacle")):
        return [], "component_difference_dominates"
    return sorted(r["direction_deg"] for r in rows), "near_minimum"


def sample(master_seed, run_id, agent_id, episode_seq):
    integer(master_seed, 0, 2**32-1)
    ref(run_id); ref(agent_id)
    integer(episode_seq, 1, 1920)
    key = [master_seed, run_id, agent_id, episode_seq, SAMPLER]
    seed = digest(key)
    n, pool, order = int(seed, 16), list(DIRECTIONS), []
    while pool:
        index = n % len(pool)
        n //= len(pool)
        order.append(pool.pop(index))
    # Unique ranks separate exact symmetry, including a final numerical tie.
    # Directions describe the current body frame, not a remembered World ray.
    return dict(seed_inputs=key, seed=seed, sampler_version=SAMPLER,
                vector=[dict(direction_deg=angle, rank=order.index(angle),
                    perturbation=(order.index(angle)-2)*.025) for angle in DIRECTIONS])


def calculate_tie_break(observation, mode, master_seed, episode_seq=1):
    """Pure current-frame evaluation. No World truth or episode state input."""
    require(isinstance(mode, str) and mode in MODES, "tie_break_mode")
    t = calculate_terrain(observation)
    eligible, reason = near_minimum(t)
    source = t["context"]
    draw = sample(master_seed, source["run_id"], source["agent_id"], episode_seq) if eligible and mode == "frozen" else None
    vector = {r["direction_deg"]: r for r in draw["vector"]} if draw else {}
    rows = []
    for r in t["directional_samples"]:
        angle, observed = r["direction_deg"], r["total"]
        applied = draw is not None and angle in eligible
        contribution = vector[angle]["perturbation"] if applied else None
        rows.append(dict(direction_deg=angle, observation_status=r["status"],
            application_status="applied" if applied else ("disabled" if mode == "disabled" else "not_applicable"),
            observed_terrain_total=observed, tie_break_perturbation=contribution,
            final_total=observed + contribution if applied else observed,
            rank=vector[angle]["rank"] if applied else None))
    action, selected_reason = terrain_action(t)
    final_minima = t["minimum_directions"]
    if draw:
        candidates = [r for r in rows if r["direction_deg"] in eligible]
        minimum = min(r["final_total"] for r in candidates)
        tied = [r for r in candidates if abs(r["final_total"]-minimum) <= TIE_TOLERANCE]
        final_minima = [r["direction_deg"] for r in tied]
        angle = min(tied, key=lambda r: r["rank"])["direction_deg"]
        action = ["move", 1] if angle == 0 else ["turn", angle]
        selected_reason = "perturbed_near_minimum"
    return dict(schema=SCHEMA, mode=mode, sampler_version=SAMPLER,
        near_width=NEAR_WIDTH, max_height=MAX_HEIGHT, eligible_directions=eligible, eligibility_reason=reason,
        observed_terrain=t, directional_samples=rows, sample=draw, final_minimum_directions=final_minima,
        selected_action=action, selected_reason=selected_reason,
        lateral_tendency="neutral", turn_hysteresis="disabled")


class TieBreakResourceAgent(TerrainResourceAgent):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.tie_break_mode = None

    def _decision(self, p):
        d = super()._decision(p)
        prior = next(reversed(self.decisions.values())) if self.decisions else None
        old = prior["tie_break"] if prior else None
        seq = old["episode_seq"] if old else 0
        episode = old["episode"] if old else None
        t = d["movement_terrain"]
        eligible, reason = near_minimum(t) if t else ([], d["terrain_gate"])
        observed = terrain_input(p, self.teaching["appearance"], d["blocked_targets"]) if t else None
        food_refs = sorted(x["ref"] for x in observed["food"]["items"]) if observed else []
        previous = next(reversed(self.observations.values())) if self.observations else None
        operation = "op:" + previous["observation_id"] if previous else None
        receipt = self.results.get(operation)
        close = None
        if episode:
            if not eligible:
                close = reason
            elif p["capture_us"] >= episode["expires_us"]:
                close = "capture_deadline"
            elif episode["uses"] >= MAX_DECISIONS:
                close = "decision_budget"
            elif p["sample_seq"] != previous["sample_seq"] + 1:
                close = "observation_gap"
            elif eligible != episode["eligible_directions"] or food_refs != episode["food_refs"]:
                close = "candidate_context_changed"
            elif not receipt or receipt["status"] not in ("turned", "waited") or (
                receipt["after_pose_ref"] != p["pose_ref"] or receipt["after_revision"] != p["body_revision"] or
                receipt["executed_us"] >= p["capture_us"] or
                p["capture_us"] >= self.commands[previous["observation_id"]]["expires_us"]):
                close = "body_continuity_unavailable"
        closed_ref = episode["ref"] if episode and close else None
        if close:
            episode = None
        transition = "inactive"
        if eligible and self.tie_break_mode == "frozen":
            if episode:
                episode = deepcopy(episode)
                episode["uses"] += 1
                transition = "reused"
            else:
                seq += 1
                transition = "started"
                episode = dict(ref=f"{self.run_id}:{self.agent_id}:tie:{seq}",
                    start_source=p["observation_id"], start_capture_us=p["capture_us"],
                    expires_us=min(p["capture_us"]+LIFETIME_US,
                        (p["capture_us"]//PERIOD_US+1)*PERIOD_US, self.periods*PERIOD_US),
                    uses=1, eligible_directions=eligible, food_refs=food_refs)
        evaluation = calculate_tie_break(observed, self.tie_break_mode, self.seed, max(seq, 1)) if observed else None
        if evaluation:
            evaluation["baseline_action"], evaluation["baseline_reason"] = list(d["action"]), d["reason"]
            if evaluation["sample"]:
                d.update(action=list(evaluation["selected_action"]), target="", reason="observed_material_tie_break")
        d["tie_break"] = dict(episode_seq=seq, episode=episode, transition=transition,
            closed_episode_ref=closed_ref, closure_reason=close, previous_operation=operation,
            evaluation=evaluation)
        return d

    def snapshot(self):
        state = super().snapshot()
        state.update(movement_control=SCHEMA, tie_break_mode=self.tie_break_mode)
        return state


class TieBreakResourceExploration(TerrainResourceExploration):
    schema = SCHEMA
    agent_type = TieBreakResourceAgent

    def dispatch(self, name, value):
        if name != "configure":
            return super().dispatch(name, value)
        with self.lock:
            fields(value, "schema run_id world_epoch agent_id clock_id teaching selection_profile tie_break_mode")
            mode = value["tie_break_mode"]
            require(isinstance(mode, str) and mode in MODES, "tie_break_mode")
            require(isinstance(value["agent_id"], str) and value["agent_id"] in self.agents, "unknown_agent")
            agent = self.agents[value["agent_id"]]
            require(agent.tie_break_mode in (None, mode), "tie_configuration_conflict")
            response = super().dispatch(name, {k: deepcopy(v) for k,v in value.items() if k != "tie_break_mode"})
            agent.tie_break_mode = mode
            return dict(response, tie_break_mode=mode)
