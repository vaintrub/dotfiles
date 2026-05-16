# Global rules for Claude

## Saving portable settings

When the user asks to save anything globally — a rule, setting, alias, binding, skill, plugin enable, hook — **run the `save-to-dotfiles` skill**. It walks three gates (portability / platform / routing) and edits the right target in the chezmoi source dir.

Never write to `~/.claude/<X>` or `~/.codex/<X>` directly — these paths are chezmoi-managed: edits there get overwritten on the next `chezmoi apply` (or surface as drift the user has to clean up). Use `chezmoi cd` to enter the source dir, then edit `dot_claude/<X>` / `dot_codex/<X>`. The full source↔target mapping and per-area guidance live in `AGENTS.md` at the source-dir root, which Claude auto-loads when cwd is anywhere in the repo.

---

## Git commits
- NEVER add "Co-Authored-By: Claude" or any other Claude/AI mentions to commits
- Commits look like regular human commits (clear, present tense, max 72-char summary)
- Branch names: kebab-case, prefixed with `feature/`, `fix/`, `docs/`, `chore/`
- Always create NEW commits rather than amending unless explicitly requested
- Never run destructive git operations (push --force, reset --hard, branch -D) without explicit confirmation

## Stack
- **Go**: idiomatic Go, errors wrapped with context, prepared statements only, gofmt + goimports
- **Python**: 3.10+, type hints required, `ruff` for lint+format (not black/isort separately), `uv` for envs
- **TypeScript/React/Astro**: strict mode, ESLint flat config, Prettier separately (not eslint-plugin-prettier)
- **PostgreSQL**: parameterized queries, migrations versioned, never drop columns (deprecate first)
- **Kubernetes**: `kubectl` read-only by default; explicit confirmation before `delete`/`apply` on shared clusters

## Tool preferences
- Use Read/Edit/Write/Bash dedicated tools (NOT cat/sed/awk/echo via Bash)
- Prefer `rg` over `grep`, `fd` over `find` when available
- For long-running commands, use `run_in_background: true`
- Quote file paths with spaces in shell commands

## Code style defaults
- Indent: 2 spaces (TS/JS/YAML/JSON), 4 spaces (Python/Go uses tabs natively)
- Line length: 100 chars max
- Quotes: double quotes (TS/JS strings), no semicolons in TS unless config says otherwise
- No comments unless WHY is non-obvious

## Workflow
- Plan before code for non-trivial changes; show plan first
- Don't add features, abstractions, or error handling beyond what's needed
- Don't add backwards-compat shims if the user hasn't asked for them
- Update existing files; only create new files when explicitly required
- For UI/frontend changes, mention if you cannot actually run/test the UI

## Security
- No secrets in code; use env vars / direnv / 1Password
- Never commit `.env*`, credentials, tokens
- Validate input only at system boundaries (user input, external APIs) — trust internal code
- Warn before destructive operations on shared systems

## Anti-patterns (don't do)
- Don't write multi-paragraph docstrings or comment blocks
- Don't reference current task/fix/caller in code comments ("added for X flow")
- Don't validate scenarios that can't happen
- Don't summarize what was just changed in chat — the diff speaks for itself
- Don't ask for confirmation on routine reversible edits

## Working principles by project type

Detailed rules live under `dot_claude/rules/` in the chezmoi source dir (use `chezmoi cd` to navigate; materialized as `~/.claude/rules/*.md` on apply) and **auto-load at session start** (universal rules always; frontend rules when working on `.tsx/.css/.astro/.svelte/.vue/...` files via `paths:` frontmatter). The list below is a human-readable TL;DR index — the rule files themselves are the source of truth.

### Universal (any project, always loaded)

- **`read-codebase-first`** — Read specs / docs / configs / tests before first fix attempt. Don't hack from assumptions.
- **`no-code-without-go`** — Any non-trivial edit (new feature, iteration, visual bug fix) → propose first, wait for explicit user `go`, then code. Exceptions: typos / lint fixes / commands the user already directed.
- **`verify-before-fix`** — Don't trust verbal descriptions of bugs. Ask for screenshots / logs / measurements before fixing.

### Frontend / visual-design (loaded when editing FE files)

- **`frontend-spec-first-workflow`** — Strict per-block pipeline: SPEC → user approve → IMPL DESKTOP → review → IMPL MOBILE → review → POLISH → COMMIT. No phase advances without explicit `go`.
- **`visual-audit-mcp-gotchas`** — Three-layer viewport conflicts (window + DevTools + MCP emulate), `resize_page` vs `emulate`, screenshot timeout recipe (pause videos + cancel animations + JPEG), `Cmd+Shift+R` after preview rebuild.

### Backend / data / library projects

Placeholder for future rule files. Likely candidates:

- Tests-first where reasonable
- Migration safety (don't drop columns; deprecate first)
- Schema/API changes through explicit review
- Logs as evidence (since no visual feedback)

@RTK.md
