# CSS Has Selector

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/css-has-selector
**Verification:** direct-page

> One line of CSS. The whole card reacts to its own checkbox.

## Source-derived guidance

Design Motion presents `:has()` as a parent selector that lets CSS react to state already present in the DOM. Its examples include styling a card from a checked child, styling validation from `:user-invalid`, escalating invalid state to the form, changing layout when a sidebar exists, using child-count queries, and reacting to an open dialog at the document level.

## Core principle

Prefer deriving presentation from state the browser and DOM already know rather than duplicating that state in application code when CSS can express the relationship safely.

## Rules

- Use `:has()` when the relevant state already exists in the DOM, such as `:checked`, `[open]`, invalid fields, or child presence/count.
- Prefer `:user-invalid` for validation styling when the goal is to avoid showing errors on the initial render.
- Put related visual changes on the container when one DOM state should update its border, label, icon, or other descendants together.
- Use CSS relational selectors for layout relationships when the DOM itself is the source of truth.
- Keep application state in JavaScript/React when the state represents business logic, server state, or behavior that CSS cannot safely own.

## Do

- Let the DOM drive purely presentational relationships when the state is already exposed there.
- Use `:has()` to reduce unnecessary derived UI state and class toggling.
- Test relational selectors across the supported browsers and input states.

## Don't

- Mirror DOM state into React state only to toggle a class that CSS can already derive.
- Count children in JavaScript just to choose a layout when a CSS quantity query is sufficient.
- Move business logic into CSS merely because `:has()` can express a visual condition.

## Agent action

When reviewing a component, look for presentation state that is already represented in the DOM. If the requested UI change can be expressed cleanly with `:has()` or another relational selector, prefer that over adding redundant component state—but keep behavioral and business state in the application layer.
