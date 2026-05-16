---
name: frontend-spec-first-workflow
description: Frontend / visual-design projects — strict per-block SPEC → IMPL DESKTOP → IMPL MOBILE → POLISH → COMMIT pipeline with user review checkpoint at every phase.
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.astro"
  - "**/*.svelte"
  - "**/*.vue"
  - "**/*.html"
  - "**/*.css"
  - "**/*.scss"
  - "**/*.sass"
---

**Rule:** On marketing sites, landing pages, design-heavy frontend work — every block / section / major component follows a 5-phase pipeline. Each phase ends with an explicit user-review checkpoint. **Nothing advances without explicit `go`.**

```
Phase 1 — SPEC
  Write notes/specs/0N-<block>.md (or equivalent).
  Contains: desktop wireframe + mobile wireframe (separately designed, not
  "scaled") + content/props shape + animation rules + reduced-motion fallback
  + a11y considerations + asset list.

  Checkpoint: user reads spec, approves or requests edits.

Phase 2 — IMPL DESKTOP
  Implement the block targeting ≥ 768 px only.

  Run visual-audit at desktop viewports.

  Checkpoint: user reviews screenshots. Approves or requests changes.

Phase 3 — IMPL MOBILE
  Implement mobile layout (≤ 767 px). May have different DOM — sections
  merged, dropped, or reordered. Different assets / copy lengths allowed.

  Run visual-audit at mobile viewports.

  Checkpoint: user reviews screenshots.

Phase 4 — POLISH
  - prefers-reduced-motion fallback verified.
  - a11y review: focus order, aria, semantic HTML, contrast.
  - Lighthouse mobile + desktop within budgets.

  Checkpoint: user approves polished block.

Phase 5 — COMMIT + MERGE
  Conventional commit, move to next block.
```

**Why:** Without this workflow, every "let me iterate on X" turns into:
- I make N changes at once
- User reviews them all
- User likes 1 of 3
- I revert 2
- User says "wait that's not quite what I meant for #1 either"
- Iterate from scratch on what should have been a 5-line spec

The Hero Phase 2 iteration cycle on calliope (2026-05-12) demonstrated this: a single "make background nicer + cursor animation + handle new video + fix video bottom corner" produced ~3 hours of revert-rebuild cycles before settling, when 30 minutes of "here's what I'd change, go?" would have done it.

**How to apply:**

1. When user says "let's iterate on the Hero" — DO NOT start editing. Write the proposal in chat or update the spec file first.
2. Per-block spec files live under `notes/specs/0N-<block-name>.md` (calliope convention) or wherever the project's spec convention dictates.
3. Each iteration on a SHIPPED block also follows this — spec the iteration before applying.
4. The workflow is reduced (skip mobile phase) when the user explicitly says "desktop only" — but still SPEC → IMPL → REVIEW → COMMIT.
5. Related rules: [[no-code-without-go]], [[verify-before-fix]], [[visual-audit-mcp-gotchas]].
