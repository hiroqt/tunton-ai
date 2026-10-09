# Drag and Drop

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/drag-and-drop
**Verification:** direct-page

> The board does the thinking: moving a card is moving state.

## Core principle

Dragging should communicate lift, destination, scope, and recovery. The interface should make valid drop targets obvious before release.

## Rules

- Use visual lift cues such as scale, shadow, or tilt.
- Preview valid destinations during the drag.
- Match the drop indicator to the destination semantics.
- Snap to valid slots on structured surfaces.
- Provide an undo path after a mistaken drop.

## Do

- Make the dragged item feel distinct from the surface.
- Show where it can land.
- Support recovery from accidental moves.

## Don’t

- Make users guess valid destinations.
- Use free positioning when the surface is slot-based.
- Make a mistaken drop expensive to undo.
