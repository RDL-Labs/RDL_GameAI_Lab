class_name ObservationResolutionProfile
extends RefCounted

const PROFILE_VERSION = "rho-profile-selection-v1"
const DEFAULT_LEVEL = "MID"
const SUPPORTED_DOMAINS = ["food"]
const SUPPORTED_LEVELS = ["LOW", "MID", "HIGH"]

var _assignments = {}

func configure(assignments):
	var candidate = {}
	for agent_id in assignments:
		if str(agent_id).is_empty() or typeof(assignments[agent_id]) != TYPE_DICTIONARY:
			return false
		candidate[agent_id] = {}
		for domain in assignments[agent_id]:
			var level = str(assignments[agent_id][domain]).to_upper()
			if not SUPPORTED_DOMAINS.has(domain) or not SUPPORTED_LEVELS.has(level):
				return false
			candidate[agent_id][domain] = level
	_assignments = candidate.duplicate(true)
	return true

func select(agent_id, domain):
	if not SUPPORTED_DOMAINS.has(domain):
		return {}
	var level = DEFAULT_LEVEL
	var source = "default"
	if _assignments.has(agent_id) and _assignments[agent_id].has(domain):
		level = _assignments[agent_id][domain]
		source = "explicit"
	return {
		"selection_profile_version": PROFILE_VERSION,
		"assignment_source": source,
		"agent_id": agent_id,
		"domain": domain,
		"level": level,
		"authority": "GameAI-local-profile-selection; not-M_B-or-action-authority"
	}

func snapshot():
	return _assignments.duplicate(true)
