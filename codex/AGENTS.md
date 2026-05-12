# Global instructions for OpenAI Codex CLI

Loaded for every Codex session as per-user global instructions (Codex's equivalent of Claude's CLAUDE.md). Codex reads `$CODEX_HOME/AGENTS.md` at session start regardless of cwd ([source](https://github.com/openai/codex/blob/main/codex-rs/core/src/agents_md.rs)).

## Tooling setup (read this first)

All configs for **Claude Code** and **OpenAI Codex CLI** live in `~/dotfiles/{claude,codex}/`. The `~/.claude/` and `~/.codex/` directories contain symlinks pointing into the dotfiles repo.

**When modifying** settings, agents, skills, rules, or `CLAUDE.md` / `AGENTS.md` itself — **edit the dotfiles target path** (`~/dotfiles/claude/<file>` or `~/dotfiles/codex/<file>`), not the live `~/.claude/<file>` or `~/.codex/<file>` path. Edits through the symlink resolve to the same file under the hood, but always point tools at the dotfiles path to keep the source-of-truth singular and obvious to anyone reviewing diffs.

After **adding NEW files** that need to be linked into `~/.claude/` or `~/.codex/`: edit `~/dotfiles/.install.conf.yaml` to add the link mapping, then `cd ~/dotfiles && ./install` to apply.

Existing symlink layout:

| Live path | Real path |
|---|---|
| `~/.codex/AGENTS.md` | `~/dotfiles/codex/AGENTS.md` (this file) |
| `~/.codex/config.toml` | `~/dotfiles/codex/config.toml` |
| `~/.codex/skills` | `~/dotfiles/codex/skills` |
| `~/.claude/CLAUDE.md` | `~/dotfiles/claude/CLAUDE.md` |
| `~/.claude/settings.json` | `~/dotfiles/claude/settings.json` |
| `~/.claude/statusline-command.sh` | `~/dotfiles/claude/statusline-command.sh` |
| `~/.claude/agents` | `~/dotfiles/claude/agents` |
| `~/.claude/skills` | `~/dotfiles/claude/skills` |
| `~/.claude/rules` | `~/dotfiles/claude/rules` |

---

## Git commits

- NEVER add "Co-Authored-By: Codex" or any other AI mentions to commits
- Commits look like regular human commits (clear, present tense, max 72-char summary)
- Branch names: kebab-case, prefixed with `feature/`, `fix/`, `docs/`, `chore/`
- Always create NEW commits rather than amending unless explicitly requested
- Never run destructive git operations (push --force, reset --hard, branch -D) without explicit confirmation

---

## Stack defaults

- **Go**: idiomatic Go, errors wrapped with context, prepared statements only, gofmt + goimports
- **Python**: 3.10+, type hints required, `ruff` for lint+format (not black/isort separately), `uv` for envs
- **TypeScript/React/Astro**: strict mode, ESLint flat config, Prettier separately (not eslint-plugin-prettier)
- **PostgreSQL**: parameterized queries, migrations versioned, never drop columns (deprecate first)
- **Kubernetes**: `kubectl` read-only by default; explicit confirmation before `delete`/`apply` on shared clusters

---

## Working principles by project type

Detailed rule files live under `~/dotfiles/claude/rules/`. They are **agent-agnostic** — the same files are picked up by Claude Code's `~/.claude/rules/` mechanism (auto-loaded with optional `paths:` frontmatter for conditional scope). Codex doesn't have an equivalent `rules/` directory feature, so the TL;DR below is the operative instruction set; the detailed files are reference material you can read on demand if needed.

### Universal (any project)

- **`read-codebase-first`** — Read specs / docs / configs / tests before first fix attempt. Don't hack from assumptions. Sweep specs/docs/configs/tests first. See `~/dotfiles/claude/rules/read-codebase-first.md`.
- **`no-code-without-go`** — Any non-trivial edit (new feature, iteration, visual bug fix) → propose first (chat or spec), wait for user `go`, then code. Exceptions: typo / lint fix / commands the user already directed. See `~/dotfiles/claude/rules/no-code-without-go.md`.
- **`verify-before-fix`** — Don't trust verbal descriptions of bugs. Ask for screenshots / logs / measurements before fixing. See `~/dotfiles/claude/rules/verify-before-fix.md`.

### Frontend / visual-design projects (UI the user looks at)

- **`frontend-spec-first-workflow`** — Strict per-block pipeline: SPEC → user approve → IMPL DESKTOP → review → IMPL MOBILE → review → POLISH → COMMIT. No phase advances without explicit `go`. See `~/dotfiles/claude/rules/frontend-spec-first-workflow.md`.
- **`visual-audit-mcp-gotchas`** (relevant when Codex has chrome-devtools MCP enabled) — three-layer viewport conflicts, `resize_page` vs `emulate`, screenshot timeout recipe (pause videos + cancel animations + JPEG), `Cmd+Shift+R` after preview rebuild. See `~/dotfiles/claude/rules/visual-audit-mcp-gotchas.md`.

### Backend / data / library projects

Placeholder for future rule files. Likely candidates:

- Tests-first where reasonable
- Migration safety (don't drop columns; deprecate first)
- Schema/API changes through explicit review
- Logs as evidence (since no visual feedback)
