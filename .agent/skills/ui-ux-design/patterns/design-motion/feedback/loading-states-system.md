# Loading States System

**Category:** feedback
**Source:** https://designmotionhq.com/patterns/loading-states-system
**Verification:** direct-page

> Stop using skeletons for everything. Loading is a system, not a default.

## Core principle

Loading feedback should match what is known about the content, duration, and progress. Skeletons, spinners, progress bars, and optimistic UI solve different problems.

## Rules

- Use skeletons when content shape is known and the wait is long enough to justify them.
- Use spinners for short waits of unknown duration.
- Use progress for longer operations when progress is measurable.
- Use optimistic UI for safe, reversible mutations.
- Avoid flashing loading indicators for extremely short waits.

## Do

- Choose loading feedback based on wait characteristics.
- Communicate meaningful progress when possible.
- Keep reversible interactions feeling immediate.

## Don’t

- Use skeletons everywhere by default.
- Show an endless spinner for long full-page operations.
- Flash loading UI for negligible waits.
