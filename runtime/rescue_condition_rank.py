"""Shared SOC-1/SOC-3 ordering; callers own evidence and eligibility."""
CONDITIONS = ("solo", "joint")


def rank_rescue_conditions(rows):
    return sorted((r for r in rows if r["available"] and not r["failed_this_episode"]),
                  key=lambda r: (-r["success_episode_count"], r["failure_episode_count"], CONDITIONS.index(r["condition"])))
