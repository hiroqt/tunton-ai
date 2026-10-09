# TUNTON documentation map

The product and implementation contracts are located in this `docs/` folder. Start with this map when you need to find the right source or give an AI agent a bounded task.

## Read in this order

1. [`../AGENTS.md`](../AGENTS.md) — agent scope, P0 gate, and required reporting.
2. [`PRD.md`](PRD.md) — product requirements, acceptance criteria, and exclusions.
3. [`ARD.md`](ARD.md) — approved files, packages, data contracts, and code ownership.
4. [`ARCHITECTURE.md`](ARCHITECTURE.md) — runtime boundaries and data flow.
5. [`SETUP.md`](SETUP.md) — environment, asset preparation, build, and offline verification.
6. [`../SKILL.md`](../SKILL.md) — implementation sequence and task procedure.
7. [`../README.md`](../README.md) — user and judge overview; it does not expand scope.

## Development map

- [`DEVELOPMENT_MAP.md`](DEVELOPMENT_MAP.md) — current checkout, approved Flutter target tree, P0 ownership, and change boundaries.

## Authority

`PRD.md` sets product scope. `ARD.md` sets the approved implementation surface. `ARCHITECTURE.md` explains the runtime. `AGENTS.md` applies the scope gate to agent work. If they disagree, stop and identify the conflict; do not create a new interpretation in this folder.

Keep implementation details in the governing root documents where they belong. Add a document here only when it provides a useful index or a focused guide without creating a second source of truth.
