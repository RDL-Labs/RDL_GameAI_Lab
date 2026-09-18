class_name ObservationResolutionAdapter

const LEVELS = ["LOW", "MID", "HIGH"]
const FOOD_RULE_VERSION = "rho-food-projection-v1"

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
