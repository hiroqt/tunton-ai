# Bulk Actions

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/bulk-actions
**Verification:** direct-page

> Bulk actions are a system, not a lone checkbox.

## Core principle

Treat selection as application state, not just DOM state; make partial selection explicit and communicate the exact scope of bulk selection. Use undo for low-friction recovery after destructive bulk operations.

## Rules

- Header selection should support empty / partial / checked states.
- Expose the exact number of matching items when select-all scope exceeds the visible page.
- Keep selected IDs stable across pagination/filter changes.
- Prefer an undo window for recoverable bulk deletion over unnecessary confirmation friction.

## Do

- Show an indeterminate selection state.
- Keep scope/count live as filters change.
- Offer a short undo period after destructive bulk operations.

## Don’t

- Use a two-state master checkbox when partial selection exists.
- Label selection vaguely as “all” when the scope is larger.
- Store selection only in visible row DOM state.
