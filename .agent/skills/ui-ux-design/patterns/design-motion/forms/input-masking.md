# Input Masking

**Category:** forms
**Source:** https://designmotionhq.com/patterns/input-masking
**Verification:** direct-page

> Type 16 digits. Watch them become a card.

## Core principle

Formatting should reduce cognitive load without fighting typing. Keep presentation separate from stored values and preserve caret behavior.

## Rules

- Group long numeric strings into readable chunks.
- Preserve caret position while formatting.
- Validate at a sensible time rather than flagging incomplete input.
- Normalize pasted values before storing.
- Display formatted values but store canonical raw data where appropriate.

## Do

- Format for scanning.
- Handle pasted input gracefully.
- Keep display and persistence concerns separate.

## Don’t

- Reject otherwise valid pasted formatting.
- Jump the caret unexpectedly.
- Persist presentation separators when the backend needs canonical data.
