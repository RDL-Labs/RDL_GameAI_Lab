extends "res://scripts/heavy_rescue_fixture.gd"
# SOC-3 fixture only. Body execution inspects binding/choice fields, not profile or evidence.
var binding = {}
var active_choice = {}
var applied_choices = {}
var expected_request = ""
var choice_consumed = false
var closed = false
var blocked_reason = ""
var execution_refs = []
var action_choices = []

func configure(value):
	binding = value.duplicate(true)
	run_id = binding["world_run_id"]

func available_conditions():
	var result = ["defer"]
	var actor = body_states.get(binding["agent_id"], {})
	var target = body_states.get(binding["target_id"], {})
	if actor.get("incapacitated", true) or actor.get("movement_scale", 0.0) <= 0.0 or not target.get("incapacitated", false): return result
	result.append("solo")
	var helper = body_states.get(binding["helper_id"], {})
	if not helper.get("incapacitated", true) and helper.get("movement_scale", 0.0) > 0.0 and helper.get("carried_agent_id", "").is_empty():
		if get_agent(binding["helper_id"])["position"].distance_to(get_agent(binding["target_id"])["position"]) <= RESCUE_REACH_DISTANCE:
			result.append("joint")
	return result

func expect_choice(request_id):
	if closed or applied_choices.size() >= 3 or not expected_request.is_empty(): return false
	if not active_choice.is_empty() and (not choice_consumed or not body_states[binding["agent_id"]]["carried_agent_id"].is_empty()): return false
	expected_request = request_id
	return true

func apply_choice(result):
	if result.get("schema", "") != "soc3-selection-guided-rescue-v1" or applied_choices.size() >= 3: return false
	if closed or result.get("binding", {}) != binding or result.get("request_choice_id", "") != expected_request: return false
	if result.get("source_observation_id", "") != expected_request or result.get("choice_index", 0) != applied_choices.size() + 1: return false
	var identity = result.get("choice_id", "")
	var selected = result.get("selected", "")
	if identity.is_empty() or applied_choices.has(identity) or not selected in ["solo", "joint", "defer"]: return false
	if not selected in available_conditions():
		blocked_reason = "current_condition_lost"
		return false
	active_choice = result.duplicate(true)
	applied_choices[identity] = true
	choice_consumed = false
	expected_request = ""
	participants = [binding["agent_id"], binding["helper_id"]] if selected == "joint" else [binding["agent_id"]]
	return true

func close_episode():
	closed = true
	expected_request = ""

func resolve_action(decision):
	if binding.is_empty(): return super.resolve_action(decision)
	var id = decision.get("agent_id", "")
	var source = decision.get("inspection", {}).get("observation_id", "")
	var key = id + ":" + source
	# Known action retransmissions are reads through the existing SOC-0 receipt.
	if action_receipts.has(key): return super.resolve_action(decision)
	if id != binding["agent_id"]: return {"error": "soc3_actor_mismatch"}
	var kind = decision.get("action", {}).get("type", "")
	if closed or not expected_request.is_empty() or active_choice.is_empty() or active_choice["selected"] == "defer":
		blocked_reason = "no_active_choice"
	elif kind == "rescue":
		if choice_consumed:
			blocked_reason = "choice_already_consumed"
		elif not active_choice["selected"] in available_conditions():
			blocked_reason = "current_condition_lost"
		else:
			var active = _active_carriers(binding["target_id"])
			if active != participants: blocked_reason = "current_condition_lost"
	if not blocked_reason.is_empty():
		return _record_resolution(id, kind, decision.get("action", {}).get("target_id", ""), "SOC-3 execution stopped: " + blocked_reason)
	if kind == "rescue": choice_consumed = true
	var count_before = experiences.size()
	var result = super.resolve_action(decision)
	action_choices.append({"choice_id": active_choice["choice_id"], "source_observation_id": source, "action": kind})
	for index in range(count_before, experiences.size()):
		var event = experiences[index]
		execution_refs.append({"choice_id": active_choice["choice_id"], "event_id": event["event_id"],
			"source_observation_id": event["source_observation_id"], "action": event["action"]})
	return result
