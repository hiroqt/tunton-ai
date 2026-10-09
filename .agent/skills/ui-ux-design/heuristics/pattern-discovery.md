# Pattern Discovery Heuristic

## Purpose

Find applicable UX patterns from the UI itself rather than waiting for a named pattern.

## Scan

- Identify the user's main task and repeated interactions.
- Inspect visible and hidden actions.
- Inspect component states and transitions.
- Inspect input methods: touch, mouse, keyboard, assistive technology.
- Look for friction, ambiguity, accidental actions, missing feedback, weak recovery, and high cognitive load.
- Search relevant pattern categories and pattern names for candidate solutions.
- Read candidate pattern files before recommending implementation.

## Candidate test

A pattern is a good candidate when it:

1. Addresses a real observed problem.
2. Fits the task frequency and consequence of failure.
3. Works with the actual input capabilities.
4. Fits the product's existing design language and interaction model.
5. Does not create a new hidden interaction or accessibility problem.
6. Reduces friction or ambiguity enough to justify its complexity.

## Output

For meaningful reviews, report a small set of candidates as **Strong fit**, **Possible fit**,
or **Not recommended**, with a brief reason. Include the Design Motion reference when one
exists, but do not attribute general UX reasoning to Design Motion unless the source supports it.
