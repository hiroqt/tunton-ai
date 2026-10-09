---
name: ui-ux-design
description: >
  A standalone UI/UX design reasoning skill for coding agents. Use it when
  designing, implementing, or reviewing interfaces to reason from user goals,
  hierarchy, interaction, states, feedback, accessibility, responsiveness,
  content, motion, recovery, and system consistency. Includes a first-class
  Design Motion pattern library as a reference source, but does not depend on
  Design Motion as the source of truth.
---

# UI/UX Design Reasoning Skill

## Purpose

Use this skill to make interface decisions from user intent, context, constraints,
and human interaction—not from database structure, component availability, or visual
fashion alone.

This is a standalone UX reasoning skill. Its core principles are source-independent.
The included `patterns/design-motion/` library is a first-class reference set that
adds concrete patterns and terminology, but Design Motion is not the authority of
this skill and the skill must still work when that reference library is unavailable.

## Core decision order

Before implementing or reviewing meaningful UI, reason in this order:

1. **User goal** — What is the user trying to accomplish? How frequent is it? What is
   the cost of failure?
2. **Information** — What must the user understand, compare, choose, or remember?
3. **Action model** — What actions exist, what are their consequences, and what
   affordances make those actions discoverable?
4. **State model** — What can happen before, during, and after the action?
5. **Feedback** — How does the interface acknowledge progress, completion, failure,
   or uncertainty?
6. **Recovery** — How can the user undo, retry, correct, or safely recover from
   expensive mistakes?
7. **Input capability** — Support the actual inputs in scope: keyboard, touch,
   mouse, assistive technology, coarse/fine pointer, and hybrid use.
8. **Accessibility** — Ensure semantics, focus, contrast, target size, announcements,
   non-color cues, reduced motion, and keyboard paths where applicable.
9. **Responsive behavior** — Adapt layout and interaction to available space and
   input capability; do not equate a viewport width with a device type.
10. **Visual hierarchy** — Establish priority through typography, grouping, spacing,
    contrast, alignment, density, and emphasis.
11. **Motion** — Add motion only when it communicates cause/effect, continuity,
    feedback, hierarchy, or attention.
12. **Consistency** — Prefer the product's established system unless a deliberate
    exception materially improves usability.

## Pattern discovery and selection

Patterns are solutions to recurring UX problems, not a checklist to apply wholesale.
The agent should be able to **discover pattern opportunities from the current UI**, even
when the user only asks to improve or review a component and does not name a pattern.

### Opportunity scan

Before implementation on a meaningful UI task, inspect the current interface and ask:

1. **What is the user doing?**
   Identify the primary task, repeated actions, decisions, and high-consequence actions.
2. **Where is the friction?**
   Look for extra steps, hidden actions, ambiguity, poor discoverability, weak feedback,
   confusing states, accidental actions, excessive cognitive load, or missing recovery.
3. **What interaction shape is present?**
   Examples include lists, forms, tables, navigation, wizards, search, menus, modals,
   drag interactions, touch interactions, long-running operations, and editable content.
4. **Search the pattern library for candidate solutions.**
   Use pattern titles, categories, catalog summaries, and pattern content as discovery cues.
   Check both `patterns/design-motion/` and `patterns/general/`.
5. **Validate applicability.**
   A pattern is a candidate only when its problem, context, interaction cost, and tradeoffs
   match the actual UI. A pattern should be rejected when it would add hidden behavior,
   conflict with input methods, weaken accessibility, duplicate an existing interaction,
   or solve a problem the UI does not actually have.
6. **Prefer the smallest useful set.**
   Several patterns may be related, but do not apply multiple patterns merely because they
   are available.

### Pattern opportunity examples

Use these as reasoning examples, not rigid rules:

- A touch-first list with frequent per-item actions may warrant investigating **Swipe
  Actions**.
- A list or table where users repeatedly act on many items may warrant **Bulk Actions**.
- A destructive operation with meaningful consequences may warrant **Destructive Actions**
  and, where appropriate, **Undo UX**.
- A long-running operation with ambiguous progress may warrant **Loading States System**,
  **Behind the Button**, or another feedback pattern.
- A form with unclear field lifecycle may warrant **Form Field States** and **Form
  Validation Timing**.
- An interface with hidden secondary controls may warrant **Progressive Disclosure**,
  **Context Menu**, or another discovery pattern depending on the interaction.
- A dense interface whose priority is unclear may warrant **Visual Hierarchy**, **Proximity
  Rule**, or **Grid System**.

The point of these examples is to teach the agent to look for **pattern-shaped problems**.
They are not instructions to apply the named pattern automatically.

### Pattern selection workflow

When a task has a meaningful UX concern:

1. Identify the underlying problem first.
2. Run an opportunity scan against the actual UI.
3. Generate a small candidate set of relevant patterns.
4. Read the selected pattern references before implementation.
5. Distinguish **source-derived guidance** from the agent's own UX reasoning.
6. Reject patterns that do not fit the user's context, product conventions, input methods,
   accessibility requirements, or existing interaction model.
7. Prefer an existing interaction over introducing a new pattern when both solve the problem
   equally well.
8. Explain the relationship between the problem, principle, pattern, and implementation
   decision when the task is substantial.

### Recommendation strength

When presenting pattern opportunities, classify them as:

- **Strong fit** — the current UI clearly exhibits the problem the pattern addresses.
- **Possible fit** — the pattern may help, but the benefit depends on product context or
  interaction frequency.
- **Not recommended** — the pattern was considered but would add friction, hidden behavior,
  accessibility problems, inconsistency, or unnecessary complexity.

This classification is preferred over dumping a long list of patterns.

### Reference priority

Use evidence in this order:

1. User needs and task context
2. Accessibility and platform requirements
3. Existing product behavior and design system
4. Core principles in this skill
5. Pattern libraries, including Design Motion
6. Personal taste or visual novelty

A pattern may inform a decision, but it does not override a higher-priority constraint.

## Design Motion reference library

The `patterns/design-motion/` directory contains 76 patterns from the Design Motion
pattern library, organized by its categories:

- content
- feedback
- forms
- interaction
- motion
- navigation
- visual

Use these patterns as concrete references when they map to the UX problem. They are
preserved as their own library so the agent can explicitly say when a decision is
influenced by a Design Motion pattern.

Pattern files may contain a mix of:

- **Source guidance** — information derived from the reference source.
- **Core principle** — normalized UX meaning that can be used independently.
- **Agent action** — implementation-oriented behavior for a coding agent.
- **Do / Don't** — included when there is enough basis for concrete rule-level guidance.
- **Accessibility / responsive notes** — included when relevant and supported.

Missing sections do not imply that the pattern has no UX constraints. Do not invent
source-specific rules to fill a template.

## Standalone reasoning when no pattern exists

A task does not need a named pattern to receive UX reasoning. When no pattern is a
close fit, derive the solution from the core principles and the product context.

Examples:

- A dense analytics dashboard may need clearer hierarchy and grouping even if no
  named pattern exactly matches it.
- A custom keyboard workflow should be designed from input capability, focus, state,
  and feedback principles even without a matching reference pattern.
- A novel interaction can be valid when its affordance, discoverability,
  accessibility, feedback, and recovery are sound.

## State completeness

For any meaningful interactive component, consider the applicable states before coding:

- default
- hover (when supported)
- focus-visible
- active / pressed
- selected
- loading / in-progress
- success / completed
- error
- empty
- disabled / unavailable
- partial / mixed
- offline / reconnecting where applicable

Do not add states that make no sense for the component. Do not omit a state merely
because it is inconvenient to implement.

## Feedback rules

- A user action should receive timely acknowledgement.
- Long-running work should have an explicit in-progress state.
- Completion and failure should be distinguishable.
- Feedback should appear near the action or affected content when practical.
- Do not use a loading spinner as the only explanation for a significant wait.
- Do not make users infer success from a disappearing control or unexplained layout change.

## Accessibility rules

- Prefer semantic controls over clickable generic containers.
- Every keyboard-operable interaction needs a reachable, visible focus state.
- Do not make essential information available only through hover.
- Do not use color as the only carrier of meaning.
- Use appropriate live announcements for dynamic status and errors.
- Respect reduced-motion preferences.
- Preserve sufficient target size and spacing for touch where touch is in scope.
- Keep names, labels, instructions, and errors specific enough to act on.

## Destructive and high-consequence actions

For expensive, destructive, irreversible, or privacy-sensitive actions:

1. Make the consequence clear.
2. Identify the target precisely.
3. Require intentional interaction appropriate to the risk.
4. Prevent accidental repetition where appropriate.
5. Provide undo or recovery when feasible.
6. Communicate the outcome.

Do not add confirmation dialogs to every action. Confirmation is justified by the
actual consequence, not by fear of clicks.

## Motion rules

Use motion when it helps users understand:

- where something came from or went to
- what changed
- that an action was acknowledged
- how hierarchy changes
- what deserves attention

Avoid motion that delays common tasks, creates visual noise, or exists solely to
look impressive. Prefer concise transitions and honor reduced-motion preferences.

## Implementation discipline

- Preserve existing business logic unless the requested UX fix requires a behavior change.
- Prefer exposing authoritative existing state instead of creating duplicate state.
- Reuse existing design-system primitives, tokens, and components when appropriate.
- Do not perform unrelated refactors during UX work.
- Do not redesign branding just because a pattern suggests a different aesthetic.
- Keep the implementation proportional to the problem.

## Review mode

When reviewing a UI, report findings in this order:

1. Critical usability or accessibility blockers
2. Missing or misleading states
3. Input-method incompatibilities
4. Feedback, error, and recovery problems
5. Information hierarchy and comprehension
6. Responsiveness and layout behavior
7. Motion issues
8. Cosmetic polish

For each meaningful finding, state:

- what the user experiences
- why it matters
- the applicable principle
- the applicable pattern/reference, if any
- the smallest practical fix

## Output expectations for substantial UI tasks

Before implementation, provide a concise decision summary when the task is large enough
that UX tradeoffs matter:

- primary user goal
- UX problems
- relevant principles
- relevant patterns/references
- recommended changes

After implementation, summarize:

- what changed
- which principles guided the changes
- which Design Motion patterns (if any) influenced the work
- accessibility/recovery improvements
- intentional non-changes and why

## Source and video handling

The Design Motion files are reference material, not the authority of the standalone skill.
For source-specific claims, use the verification metadata in each pattern file.

Do not claim to have learned a rule from a video unless the video was actually available
and reviewed. Text-derived pattern guidance may stand on its own. Video observations should
be treated as supplemental evidence and clearly labeled as such.
