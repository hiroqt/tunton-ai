# Autosave

**Category:** forms
**Source:** https://designmotionhq.com/patterns/autosave-ux
**Verification:** direct-page

> Saved. It wasn't. Your wifi died mid-word.

## Core principle

Autosave needs an honest state machine and recovery path: debounce writes, persist offline changes locally, handle concurrency, and guard exits when work is unsaved.

## Rules

- Debounce writes rather than saving every keystroke.
- Represent typing / saving / saved / offline / error as explicit states.
- Queue offline edits and replay them in order after reconnect.
- Handle concurrent edits explicitly rather than silently overwriting.
- Warn before leaving when unsaved work exists.

## Do

- Keep save status truthful.
- Use a local pending queue when offline.
- Resolve concurrent edit conflicts visibly.

## Don’t

- Show “Saved” before persistence succeeds.
- Silently overwrite concurrent edits.
- Close a page with unsaved work without warning.
