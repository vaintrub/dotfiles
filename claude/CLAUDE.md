# Global rules for Claude

## Tooling setup (read this first)

All configs for **Claude Code** and **OpenAI Codex CLI** live in `~/dotfiles/{claude,codex}/`. The `~/.claude/` and `~/.codex/` directories contain symlinks pointing into the dotfiles repo.

**When modifying** settings, agents, skills, rules, or `CLAUDE.md` / `AGENTS.md` itself — **edit the dotfiles target path** (`~/dotfiles/claude/<file>` or `~/dotfiles/codex/<file>`), not the live `~/.claude/<file>` or `~/.codex/<file>` path. Edits through the symlink resolve to the same file under the hood, but always point tools at the dotfiles path to keep the source-of-truth singular and obvious to anyone reviewing diffs.

After **adding NEW files** that need to be linked into `~/.claude/` or `~/.codex/`: edit `~/dotfiles/.install.conf.yaml` to add the link mapping, then `cd ~/dotfiles && ./install` to apply.

Existing symlink layout:

| Live path | Real path |
|---|---|
| `~/.claude/CLAUDE.md` | `~/dotfiles/claude/CLAUDE.md` |
| `~/.claude/settings.json` | `~/dotfiles/claude/settings.json` |
| `~/.claude/statusline-command.sh` | `~/dotfiles/claude/statusline-command.sh` |
| `~/.claude/agents` | `~/dotfiles/claude/agents` |
| `~/.claude/skills` | `~/dotfiles/claude/skills` |
| `~/.claude/rules` | `~/dotfiles/claude/rules` |
| `~/.codex/AGENTS.md` | `~/dotfiles/codex/AGENTS.md` |
| `~/.codex/config.toml` | `~/dotfiles/codex/config.toml` |
| `~/.codex/skills` | `~/dotfiles/codex/skills` |

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

Detailed rules live under `~/dotfiles/claude/rules/` and **auto-load at session start** (universal rules always; frontend rules when working on `.tsx/.css/.astro/.svelte/.vue/...` files via `paths:` frontmatter). The list below is a human-readable TL;DR index — the rule files themselves are the source of truth.

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
