# Disabled Buttons

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/disabled-buttons
**Verification:** direct-page

> The button is disabled, and nobody tells you why.

## Core principle

A disabled control can hide both the problem and the recovery path. Prefer reachable explanation and validation, and distinguish disabled state from in-progress state.

## Rules

- Do not rely on a disabled button to explain what is missing.
- Explain the blocker in reachable text rather than a tooltip attached to a disabled control.
- For async operations, preserve focus and expose busy state rather than treating loading as disabled.
- Check contrast for disabled text and controls.

## Do

- Validate on activation and identify blocking fields.
- Use an explicit busy state with appropriate accessibility state.
- Keep the reason for a blocked action discoverable.

## Don’t

- Disable submit with no explanation.
- Assume a tooltip will reliably explain a disabled control.
- Grey out a control mid-request and remove the user’s place.
