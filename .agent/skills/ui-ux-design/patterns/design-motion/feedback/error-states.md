# Error States

**Category:** feedback
**Source:** https://designmotionhq.com/patterns/error-states
**Verification:** direct-page

> Same error. Better recovery.

## Core principle

Error presentation should match severity and location, tell users what happened, provide a recovery path, and validate early enough to prevent avoidable failures.

## Rules

- Match the surface to the error type and severity.
- Give every actionable error a recovery path.
- Write human-readable explanations.
- Place field validation near the field it describes.
- Use inline validation to prevent avoidable submission failures.

## Do

- Match error surface to severity.
- Say what happened and what to do next.
- Keep field-level feedback close to the field.

## Don’t

- Use a generic “Error 500” message for user-facing recovery.
- Create dead-end alerts with only an OK button.
- Separate field errors from the fields they describe.
