# Live Cursors

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/live-cursors
**Verification:** direct-page

> Three cursors land on your canvas. None of them are yours.

## Core principle

Collaborative presence should feel smooth and stable: interpolate remote movement, make identity visually persistent, prevent editing conflicts, and support follow mode.

## Rules

- Interpolate remote cursor positions between server updates.
- Derive user colors from stable identity rather than random session assignment.
- Show collaborator presence before users edit.
- Lock or otherwise arbitrate conflicting edits.
- Allow following another collaborator’s viewport when useful.

## Do

- Render smooth motion from sparse network updates.
- Keep identity colors stable.
- Prevent simultaneous destructive edits to the same object.

## Don’t

- Render only raw server ticks.
- Randomize identity colors each session.
- Allow conflicting edits to the same object without arbitration.
