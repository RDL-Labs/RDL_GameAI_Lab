"""Frozen GameAI-local retry tendency; not a full personality or Core M_B."""

from dataclasses import dataclass
from types import MappingProxyType


@dataclass(frozen=True)
class RetrySensitivityProfile:
    profile_id: str
    retry_ticks: int


RETRY_PROFILES = MappingProxyType({
    "short": RetrySensitivityProfile("retry-short-v1", 1),
    "standard": RetrySensitivityProfile("retry-standard-v1", 3),
    "long": RetrySensitivityProfile("retry-long-v1", 5),
})


def parse_retry_profiles(assignments):
    result = {}
    for assignment in assignments:
        agent, separator, name = assignment.partition("=")
        if not separator or not agent.strip() or agent != agent.strip() or name not in RETRY_PROFILES:
            raise ValueError("retry profile must be AGENT=short|standard|long")
        if agent in result:
            raise ValueError(f"duplicate retry profile for {agent}")
        result[agent] = name
    return result
