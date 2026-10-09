# Behind the Button

**Category:** interaction
**Source:** https://designmotionhq.com/patterns/behind-the-button
**Verification:** direct-page

> Six things happen before the spinner stops.

## Core principle

A button click crosses trust boundaries. Validate quickly on the client, validate authoritatively on the server, use a transaction for related writes, repaint with server truth, and reserve optimistic UI for reversible actions.

## Rules

- Client validation improves speed; server validation enforces trust.
- Recompute sensitive values such as prices on the server.
- Use transactions for multi-record writes that must succeed or fail together.
- Render authoritative IDs/results from the server response.
- Avoid optimistic UI for payments or irreversible actions.

## Do

- Validate on both client and server.
- Recompute totals from trusted server data.
- Use transactions for atomic multi-row changes.
- Use optimistic UI for cheap, reversible interactions.

## Don’t

- Trust client-supplied price or totals.
- Allow partial writes for one logical operation.
- Optimistically confirm irreversible financial actions.
