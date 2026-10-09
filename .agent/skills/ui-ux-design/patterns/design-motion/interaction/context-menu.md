# Context Menu

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/context-menu
**Verification:** direct-page

> A context menu is a system, not just a list of actions.

## Core principle

A context menu is a responsive command surface: it must stay inside the viewport, group actions by intent, support keyboard control, protect submenus, and have a touch equivalent.

## Rules

- Position or flip the menu to stay within the viewport.
- Group actions by intent and separate destructive commands.
- Use hover intent/safe geometry for submenu travel.
- Support arrows, Enter, and Escape for keyboard interaction.
- Provide a long-press equivalent on touch devices.

## Do

- Adapt menu placement to available space.
- Group commands.
- Provide keyboard and touch pathways.

## Don’t

- Let menus clip off-screen.
- Dump unrelated commands into one flat list.
- Make right-click the only trigger.
