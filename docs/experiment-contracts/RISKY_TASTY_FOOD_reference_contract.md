# Risky Tasty Food Reference Contract

## Purpose

Introduce one finite value gradient and one physical Territory risk path without
granting Dynamic `M_B` or external statements game action authority.

## Separated Inputs

```text
Godot World facts
  ordinary_food / NORMAL
  tasty_food / HIGH / located in north_grove
  beast_1 / north_grove geometry

God Statue information
  source-attributed statement: tasty_food is tasty

Embodied consequence
  approach tasty_food
  -> territory warning
  -> chase
  -> attack / physical injury
  -> agent-owned Territory Experience
```

The Food records contain no `danger`, `dangerous`, or `threat_score` field. The
God Statue statement is information with provenance, not World Truth.

## Experience Relation

The existing Territory Experience record may carry this finite context:

```text
action
food_id
food_desirability_fixture
territory_id
```

The context does not label the Food or Beast as dangerous. Warning, chase,
attack, and injury remain sourced World events and consequences.

## Authority

```text
desirability_fixture != H != theta_eff != rho
God Statue statement != World Truth != M_B
Territory Experience != H
CandidateRelation != danger truth
canonical evaluator cutover != game action authority
```

## Acceptance

1. Godot contains ordinary and tasty Food in the same opt-in fixture.
2. Tasty Food has a physical `territory_id` relation to the Beast territory.
3. The God Statue statement preserves source, subject, predicate, polarity, and authority.
4. No Food object carries an NPC danger meaning field.
5. Tasty approach reuses warning, chase, attack, and injury from Territory Beast.
6. Direct Experience preserves agent, Food, Beast, territory, action, outcome, and consequence.
7. Ordinary Food creates no Territory event merely because the fixture exists.
8. Neither statement nor Experience mutates canonical state or action policy.

## Deferred

Preference learning, trust, expected utility, Sleep adapter for Territory
Experience, candidate admission, and `M_B`-based action differences remain
separate later phases.
