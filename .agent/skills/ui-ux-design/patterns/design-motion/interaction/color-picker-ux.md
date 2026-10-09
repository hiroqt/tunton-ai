# Color Picker UX

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/color-picker-ux
**Verification:** direct-page

> Pick a color. Your whole UI answers.

## Core principle

A color picker is a decision tool with downstream consequences. It should remember choices, expose useful representations, validate contrast live, and preview transparency honestly.

## Rules

- Treat color selection as part of a system rather than an isolated gradient.
- Expose a readable color representation such as OKLCH alongside hex when useful.
- Provide recent swatches and saved palettes.
- Validate contrast during selection.
- Preview alpha against more than a plain white background.
- Generate related color tokens where appropriate.

## Do

- Make consequences visible while choosing color.
- Keep recent/saved choices accessible.
- Validate accessibility as part of the decision.

## Don’t

- Ship only a bare gradient slider.
- Check contrast only during final review.
- Preview transparency only on white.
