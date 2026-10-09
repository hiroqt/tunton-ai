# Settings System

**Category:** forms
**Source:** https://designmotionhq.com/patterns/settings-system
**Verification:** direct-page

> Your settings page is harmless until the last section. Settings is a system.

## Core principle

Settings should be organized around user tasks and risk, not the data model. Apply behavior, reset controls, search, advanced sections, and destructive areas all matter.

## Rules

- Match instant-vs-save apply behavior to risk and scope.
- Group settings by user task.
- Provide settings search for large collections.
- Show which values changed and allow per-setting reset.
- Isolate destructive actions and add deliberate confirmation friction.
- Hide advanced options until needed without burying them.

## Do

- Use instant changes for low-risk toggles when appropriate.
- Use explicit save/cancel for identity-sensitive edits.
- Require strong confirmation for irreversible deletion.

## Don’t

- Dump settings in schema order.
- Fire irreversible actions from an unguarded click.
- Force users through deep menus when search is more efficient.
