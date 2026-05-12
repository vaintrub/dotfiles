---
name: no-code-without-go
description: Universal — no code edit on a non-trivial change without an explicit "go" from the user.
---

**Rule:** On any non-trivial edit — new feature, iteration on existing component, visual bug fix, refactor — the next response is a **proposal**, not a code change. Wait for explicit user `go` / `apprоve` / `OK` before touching `src/**` / implementation files.

Exceptions:
- Typo fixes / Prettier reformatting / lint auto-fixes.
- A specific change the user just directed in this turn ("fix that typo", "remove the `console.log`").
- Doc-only edits (notes/, docs/, AGENTS.md, ADR, README) — those are free without pre-approval, since they're reversible and discussion-friendly.

**Why:** During Hero Phase 2 (calliope, 2026-05-12), I repeatedly translated user requests into immediate code:

> User: "background looks boring, let's make it nicer + cursor animation + new video + video bottom corner is missing"
> Me: *writes all four changes in one shot, ships, asks user to look*

This pattern:
1. Wastes screenshot-review-revert cycles when one of the four guesses is wrong.
2. Makes the user feel they don't have control over which direction the design goes.
3. Locks the design into my interpretation before the user has a chance to redirect.

The user said explicitly:

> «Опять сильно поторопился! Убежал без спеки, ты можешь запомнить, что так нельзя делать никогда — пока я явно не скажу!?»

The schedule cost is real. Spec-first stops being abstract overhead when you count the wasted cycles.

**How to apply:**

1. When user describes desired changes — even multiple specific ones in one message — the response should be:
   - A summary of how I'd address each one.
   - For visual changes: concrete CSS snippet or wireframe.
   - For logic changes: concrete code outline.
   - Then "go for all / go for these N / discuss" — ask explicitly.
2. Even when the fix looks obviously correct (e.g., "video bottom corner missing — it's the asymmetric mask"), spec the fix in 3-5 lines before editing.
3. The only auto-execute trigger is the user's literal `go` / `apprоve` / `сделай` / `можно` — for the **specific** thing just discussed, not adjacent refinements.
4. If the user is in "auto mode" but they've explicitly said "spec-first" earlier — spec-first wins. Auto mode doesn't override an explicit standing instruction from the user.
5. Related rules: [[read-codebase-first]] (which precedes proposal), [[frontend-spec-first-workflow]] (the strict per-block protocol).
