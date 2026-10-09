# UI/UX Design Reasoning Skill

A standalone UI/UX reasoning skill for coding agents, with the 76 Design Motion patterns
preserved as a first-class reference library.

## What is included

- `SKILL.md` — source-independent UX reasoning and agent behavior
- `principles/` — foundational UX principles
- `heuristics/` — cross-cutting decision heuristics
- `patterns/design-motion/` — 76 Design Motion patterns, grouped by category
- `patterns/general/` — small set of source-independent pattern references
- `checklists/` — component and page review checklists
- `PATTERN-INDEX.md` — Design Motion catalog
- `patterns.json` — machine-readable Design Motion catalog
- `SOURCES.md` — provenance and verification notes


## Pattern discovery behavior

The skill is designed to proactively identify UX opportunities in an existing UI. An agent
should not wait for the developer to name a pattern. It should inspect the user task, current
interaction model, friction points, and input methods, then search the pattern libraries for
candidate solutions. Design Motion patterns such as `Swipe Actions`, `Bulk Actions`,
`Loading States System`, and `Destructive Actions` can therefore be recommended when the
actual UI presents the corresponding problem.

Pattern names are not commands. The agent must validate whether a candidate actually fits and
may explicitly reject it.

## Design Motion's role

Design Motion is intentionally retained as a named pattern library, not as the source of
truth for UX decisions. The standalone skill reasons from user needs, accessibility,
product context, and its own core principles first, then uses patterns as concrete solutions.

The skill can still function when the Design Motion reference directory is unavailable.

## Pattern file semantics

Pattern files may contain source guidance, normalized principles, agent actions, Do/Don'ts,
and context-specific notes. Sections are optional; absent sections must not be treated as
permission to violate a principle.
