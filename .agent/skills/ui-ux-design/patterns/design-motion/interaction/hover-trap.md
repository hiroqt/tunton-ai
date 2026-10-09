# Hover Trap

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/hover-trap
**Verification:** direct-page

> Hover works on your laptop but is dead on mobile.

## Core principle

Hover is an optional pointer enhancement, never a prerequisite for essential actions. Touch and hybrid devices require capability-based handling.

## Rules

- Never hide primary actions behind hover.
- Give hover-only secondary actions a touch-reachable alternative.
- Gate hover styles with @media (hover: hover).
- Use pointer capability rather than user-agent/device sniffing.
- Keep visible icons small but give interactive targets a generous hit area; Design Motion uses 44px as the target size.

## Do

- Use hover to reveal secondary extras.
- Use capability queries for hover.
- Support comfortable tap targets.

## Don’t

- Hide required actions behind hover.
- Detect touch by user-agent sniffing.
- Make the hit area equal only to the visible icon.
