"""OBS-9 life-profile reacquisition; no automatic action or canonical connection."""
from .visual_reacquisition import _evaluate

RULE_VERSION = "obs9-v1"
PROFILES = ("fixture-life-sensory", "fixture-life-sensory-compact")


def evaluate(snapshot, request, evidence):
    return _evaluate(snapshot, request, evidence, RULE_VERSION, PROFILES)
