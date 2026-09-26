"""OBS-8B: actual acquisition times; no retimestamping or action authority."""
from .visual_reacquisition import _evaluate

RULE_VERSION = "obs8b-v1"


def evaluate(snapshot, request, evidence):
    return _evaluate(snapshot, request, evidence, RULE_VERSION)
