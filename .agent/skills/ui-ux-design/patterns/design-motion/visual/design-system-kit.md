# Design System Kit

**Category:** visual
**Source:** https://designmotionhq.com/patterns/design-system-kit
**Verification:** direct-page

> Random hex and eyeballed pixels don't scale. A token system does.

## Core principle

A design system should encode intent in reusable tokens and component states rather than scattering hardcoded values.

## Rules

- Use semantic color tokens instead of repeated hex values.
- Maintain a systematic color scale and map it to semantic roles.
- Define a type scale with deliberate sizes and weights.
- Use a consistent spacing scale.
- Standardize components by variants, sizes, and states.
- Use a small, coherent motion duration/easing scale.

## Do

- Centralize design decisions in tokens.
- Model component variants and states explicitly.
- Keep spacing and type values systematic.

## Don’t

- Eyeball every new color or spacing value.
- Create visually similar components with unrelated states.
- Scatter motion timings throughout the codebase.
