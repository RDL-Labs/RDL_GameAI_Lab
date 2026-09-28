import copy
import unittest

from runtime.failure_response_candidates import (
    AUTHORITY,
    CANDIDATE_ORDER,
    FailureResponseCandidateError,
    expand_failure_response,
)


def failure_event():
    return {
        "schema": "soc0-rescue-experience-v1",
        "run_id": "soc5-run",
        "event_id": "soc5-failure-0",
        "agent_id": "npc_a",
        "source_observation_id": "before-failure",
        "subsequent_observation_id": "after-failure",
        "tick": 4,
        "action": "rescue",
        "target_id": "npc_b",
        "participants": ["npc_a"],
        "attempt_condition": "solo",
        "result": "carry_not_established",
        "world_consequence": {"target_moved": False, "carry_established": False},
        "body_consequence": {"actor_incapacitated": False, "target_incapacitated": True,
                             "target_recovery_stage": "none"},
        "authority": "bounded-rescue-experience-only; not-social-relation-NERV-T1-or-action",
    }


def context(**changes):
    value = {
        "schema": "soc5-post-failure-context-v1",
        "run_id": "soc5-run",
        "agent_id": "npc_a",
        "target_id": "npc_b",
        "context_ref": "soc5-heavy-rescue-followup-v1",
        "source_observation_id": "after-failure",
        "coverage": "complete",
        "actor_ready": True,
        "movement_ready": True,
        "retry_budget_remaining": 1,
        "known_tool_refs": [],
        "observed_agent_refs": ["npc_c"],
    }
    value.update(changes)
    return value


def by_name(result):
    return {row["candidate"]: row for row in result["candidates"]}


class FailureResponseCandidatesTests(unittest.TestCase):
    def test_actual_failure_expands_without_selecting(self):
        out = expand_failure_response(failure_event=failure_event(), context=context())
        self.assertEqual([r["candidate"] for r in out["candidates"]], list(CANDIDATE_ORDER))
        rows = by_name(out)
        self.assertEqual(rows["retry"]["status"], "available")
        self.assertEqual(rows["reposition"]["status"], "available")
        self.assertEqual(rows["known_tool"]["status"], "unavailable")
        self.assertEqual(rows["seek_agent"]["status"], "available")
        self.assertEqual(rows["seek_agent"]["evidence_refs"], ["npc_c"])
        self.assertNotIn("selected", out)
        self.assertNotIn("score", str(out))
        self.assertEqual(out["authority"], AUTHORITY)

    def test_known_tool_is_existing_reference_not_invention(self):
        rows = by_name(expand_failure_response(
            failure_event=failure_event(), context=context(known_tool_refs=["tool_rope"], observed_agent_refs=[])))
        self.assertEqual(rows["known_tool"]["status"], "available")
        self.assertEqual(rows["known_tool"]["evidence_refs"], ["tool_rope"])
        self.assertEqual(rows["seek_agent"]["status"], "unavailable")

    def test_partial_coverage_does_not_turn_absence_into_negative(self):
        rows = by_name(expand_failure_response(
            failure_event=failure_event(), context=context(coverage="partial", known_tool_refs=[], observed_agent_refs=[])))
        self.assertEqual(rows["known_tool"]["status"], "unresolved")
        self.assertEqual(rows["seek_agent"]["status"], "unresolved")

    def test_budget_and_body_readiness_are_finite_constraints(self):
        rows = by_name(expand_failure_response(
            failure_event=failure_event(), context=context(retry_budget_remaining=0, movement_ready=False)))
        self.assertEqual(rows["retry"]["status"], "unavailable")
        self.assertEqual(rows["reposition"]["status"], "unavailable")
        rows = by_name(expand_failure_response(
            failure_event=failure_event(), context=context(actor_ready=False)))
        for key in ("retry", "reposition", "known_tool", "seek_agent"):
            self.assertEqual(rows[key]["status"], "unavailable")
        self.assertEqual(rows["wait"]["status"], "available")
        self.assertEqual(rows["abandon"]["status"], "available")

    def test_requires_real_solo_failure_and_post_failure_observation(self):
        for edit in (
            lambda e, c: e.update(result="carry_established", world_consequence={"target_moved": False, "carry_established": True}),
            lambda e, c: e.update(participants=["npc_a", "npc_c"], attempt_condition="joint"),
            lambda e, c: c.update(source_observation_id="before-failure"),
        ):
            e, c = failure_event(), context(); edit(e, c)
            with self.assertRaises(FailureResponseCandidateError):
                expand_failure_response(failure_event=e, context=c)

    def test_hidden_answer_fields_are_rejected(self):
        for key, value in (
            ("required_carriers", 2), ("carry_load", 2), ("correct_helper_id", "npc_c"),
            ("combined_capacity", 2), ("requires_helper", True),
        ):
            c = context(); c[key] = value
            with self.assertRaisesRegex(FailureResponseCandidateError, "invalid_post_failure_context"):
                expand_failure_response(failure_event=failure_event(), context=c)

    def test_no_social_relation_or_communication_is_manufactured(self):
        out = expand_failure_response(failure_event=failure_event(), context=context())
        text = str(out).lower()
        for forbidden in ("trust", "friend", "usefulness", "call", "help", "point", "dialogueturn"):
            self.assertNotIn(forbidden, text)

    def test_inputs_and_outputs_are_frozen_and_reference_order_is_irrelevant(self):
        e, c = failure_event(), context(known_tool_refs=["tool_b", "tool_a"], observed_agent_refs=["npc_d", "npc_c"])
        before_e, before_c = copy.deepcopy(e), copy.deepcopy(c)
        out = expand_failure_response(failure_event=e, context=c)
        self.assertEqual(e, before_e); self.assertEqual(c, before_c)
        other = expand_failure_response(
            failure_event=copy.deepcopy(e),
            context=context(known_tool_refs=["tool_a", "tool_b"], observed_agent_refs=["npc_c", "npc_d"]),
        )
        self.assertEqual(out["candidate_set_id"], other["candidate_set_id"])
        out["context"].clear(); out["candidates"].clear()
        fresh = expand_failure_response(failure_event=e, context=c)
        self.assertEqual(fresh["context"]["known_tool_refs"], ["tool_a", "tool_b"])


if __name__ == "__main__":
    unittest.main()
