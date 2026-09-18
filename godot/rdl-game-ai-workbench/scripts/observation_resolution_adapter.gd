class_name ObservationResolutionAdapter

const LEVELS = ["LOW", "MID", "HIGH"]
const FOOD_RULE_VERSION = "rho-food-projection-v1"
const REST_RULE_VERSION = "rho-rest-projection-v1"

static func project_food(level, stock_band, stock_revision, food_site_visible):
	if not LEVELS.has(level):
		return {}
	var distinctions = {}
	if level == "LOW":
		distinctions = {
			"supply_status": "enough" if stock_band == "enough" else "needs_supply"
		}
	elif level == "MID":
		distinctions = {"stock_band": stock_band}
	else:
		distinctions = {
			"stock_band": stock_band,
			"stock_trend": "decreasing" if stock_revision > 0 else "stable",
			"food_site_condition": "available" if food_site_visible else "not_observed"
		}
	return {
		"profile_id": "rho-food-%s-v1" % level.to_lower(),
		"domain": "food",
		"level": level,
		"rule_version": FOOD_RULE_VERSION,
		"authority": "GameAI-local-observation-projection; not-M_B-or-action-authority",
		"distinctions": distinctions
	}

static func project_rest(level, fatigue_band, previous_fatigue_band, rest_context):
	if not LEVELS.has(level):
		return {}
	var distinctions = {}
	if level == "LOW":
		distinctions = {
			"rest_status": "not_tired" if fatigue_band in ["rested", "tiring"] else "tired"
		}
	elif level == "MID":
		distinctions = {"fatigue_band": fatigue_band}
	else:
		distinctions = {
			"fatigue_band": fatigue_band,
			"fatigue_trend": _band_trend(previous_fatigue_band, fatigue_band),
			"reachable_rest_context": rest_context.get("availability", "not_observed"),
			"safety_distinction": rest_context.get("safety", "unknown"),
			"completion_margin": _rest_completion_margin(fatigue_band)
		}
	return {
		"profile_id": "rho-rest-%s-v1" % level.to_lower(),
		"domain": "rest",
		"level": level,
		"rule_version": REST_RULE_VERSION,
		"authority": "GameAI-local-observation-projection; not-RestNeed-sleep-H-M_B-or-action-authority",
		"distinctions": distinctions
	}

static func _band_trend(previous_band, current_band):
	var order = ["rested", "tiring", "tired", "exhausted"]
	var previous_index = order.find(previous_band)
	var current_index = order.find(current_band)
	if previous_index == -1 or current_index == -1 or previous_index == current_index:
		return "stable"
	return "worsening" if current_index > previous_index else "recovering"

static func _rest_completion_margin(fatigue_band):
	if fatigue_band == "exhausted":
		return "far"
	if fatigue_band == "tired":
		return "some"
	return "near"
