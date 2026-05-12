---
name: read-codebase-first
description: Universal — read specs / docs / configs / tests before first fix attempt. Don't hack from assumptions.
---

**Rule:** Before touching code in response to a bug report or iteration request, read the relevant parts of the codebase first. Spec files, docs, configs, tests — whichever ground the change.

**Why:** Multiple times in the Hero Phase 2 session (calliope, 2026-05-12), I started writing fixes from verbal descriptions or partial code reading, only to discover the actual cause was something the spec or AGENTS.md already prescribed differently. Each premature attempt cost a screenshot-review-revert cycle. The user explicitly said:

> «Сначала прочитай документацию! Подумай получше! Сверься с спеками И так далее»

After spending ~2 hours on a misdiagnosed "horizontal scrollbar at 4K" issue, the actual diagnosis came from reading the codebase top-to-bottom: LandingLayout, Nav, Footer, global.css, tokens.css, Hero.astro. The root cause turned out to be viewport-override conflicts, not any code issue — finding that required full context.

**How to apply:**

1. When user reports a bug, before any Edit:
   - Read the file the bug seems to be in.
   - Read the parent / containing files (layout, registry).
   - Read the spec for the affected component if it exists.
   - Read AGENTS.md / CLAUDE.md / equivalent steering docs to see if there's an existing rule.
   - Read configs that touch the area (tsconfig, astro.config, package.json).
2. For greenfield iterations, re-read the spec end-to-end before proposing changes.
3. If the change is genuinely tiny (typo, lint fix), the read can be limited to that file alone — but the bias should be toward more context, not less.
4. When grepping, use `rg` not `grep`; use multiple search angles (different keywords) before assuming a thing doesn't exist.
5. Related rule: [[no-code-without-go]] — proposal precedes code; reading precedes proposal.
