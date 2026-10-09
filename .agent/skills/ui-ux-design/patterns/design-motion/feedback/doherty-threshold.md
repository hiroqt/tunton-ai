# Doherty Threshold

**Category:** feedback
**Source:** https://designmotionhq.com/patterns/doherty-threshold
**Verification:** direct-page

> Cross 400ms and your user checks out. Perceived speed is a design choice.

## Core principle

Perceived responsiveness matters as much as raw compute time. The interface should acknowledge interaction quickly and communicate longer work rather than appearing frozen.

## Rules

- Treat ~400ms as an important feedback boundary from the pattern.
- Give a visible acknowledgment quickly when work will take longer.
- Use skeletons when the shape of incoming content is known.
- Use progress when the duration/proportion of work is knowable.
- Use optimistic UI for safe, reversible actions.

## Do

- Acknowledge actions promptly.
- Use appropriate feedback for unavoidable waits.
- Optimize perceived speed, not just benchmark time.

## Don’t

- Leave the interface blank/frozen during waits.
- Wait for a full round-trip before showing any response when a safe acknowledgment is possible.
