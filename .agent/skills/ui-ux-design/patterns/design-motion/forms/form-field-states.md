# Form Field States

**Category:** forms
**Source:** https://designmotionhq.com/patterns/form-field-states
**Verification:** direct-page

> Six field states, one system. Miss one and you ship a bug.

## Core principle

A form field is a state system, not a single visual component. Explicitly design the resting, focus, error, success, disabled, and loading states.

## Rules

- Design default, focus, error, success, disabled, and loading states.
- Keep persistent labels outside the input area.
- Make focus visible and accessible.
- Combine error color with iconography/text rather than color alone.
- Show success near the field when it matters.
- Keep disabled visually distinct from loading.

## Do

- Treat all six states as part of the component contract.
- Explain errors and how to fix them.
- Protect focus during loading when appropriate.

## Don’t

- Use placeholder text as the only label.
- Rely on border color alone for errors.
- Conflate disabled and loading.
