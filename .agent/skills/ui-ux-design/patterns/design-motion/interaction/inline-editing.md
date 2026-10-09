# Inline Editing

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/inline-editing
**Verification:** direct-page

> Click the title. It's an input now, and nothing moved.

## Core principle

Inline editing works when the edit mode feels continuous: signal editability, preserve geometry, establish predictable commit/cancel behavior, and recover safely from save failure.

## Rules

- Give editable content a subtle affordance.
- Keep typography, padding, and geometry stable when swapping text for input.
- Use consistent Enter/Escape semantics and choose one blur policy.
- Optimistically update reversible edits but preserve the draft if persistence fails.
- Match editing affordance to the cost of mistakes.

## Do

- Signal editability.
- Keep the input visually aligned with the original text.
- Preserve draft text on failure.

## Don’t

- Make editable text visually indistinguishable from static text.
- Change blur behavior unpredictably.
- Discard user input after a failed save.
