# Global rules for Claude

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
