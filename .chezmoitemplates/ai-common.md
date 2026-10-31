## Saving portable settings

When the user asks to save something globally (a rule, a setting, an alias, a binding, a skill, a
plugin or a hook), **run the `save-to-dotfiles` skill**. It checks that the change is portable,
picks the platform, and edits the right file in the chezmoi source directory.

Never edit `~/.claude/<X>` or `~/.codex/<X>` directly. chezmoi manages these paths, so the next
`chezmoi apply` overwrites the edit or reports it as drift. Run `chezmoi cd` and edit
`dot_claude/<X>` or `dot_codex/<X>` there. `AGENTS.md` at the root of the source directory maps
each source to its target; it loads when the working directory is inside that repository.

---

## Before you change code

Each rule here exists because a guess cost several rounds of screenshots and reverts.

- **Read first.** Before a fix or a change, read the file it touches, the files around it, its
  spec, the repository's `AGENTS.md` or `CLAUDE.md`, and the configs of that area. Before an
  iteration on new work, read its spec again in full. Search with several keywords before you
  decide that something does not exist. For a typo or a lint fix, the file itself is enough.
- **Ask for evidence of a bug.** A bug described in words is ambiguous. Ask for a screenshot, a
  log, the error message or a measurement before you propose a fix. Measure a layout before you
  change it.
- **Propose, then wait for "go".** For a new feature, an iteration, a visual fix or a refactor,
  your next answer is a proposal: what you would change and why, with a code outline, a CSS
  snippet or a wireframe. Propose even when the fix looks obvious. Change the code only after
  the user's literal "go", "approve" or "OK", and only for the thing just discussed. An auto mode
  does not override this rule.
- **Edit without asking** when the change is a typo, a formatter or lint fix, a change that the
  user just directed, or an edit of documentation: `docs/`, `notes/`, `AGENTS.md`, ADRs, READMEs.
  Do not ask for confirmation of other routine, reversible steps either.

## Git commits

- Never add "Co-Authored-By: Claude", "Co-Authored-By: Codex" or any other mention of an AI to a
  commit.
- Write commits like a person: clear, in the present tense, with a summary of at most 72
  characters.
- Name branches in kebab-case, with a prefix: `feature/`, `fix/`, `docs/` or `chore/`.
- Create a new commit; amend only when the user asks.
- Never run a destructive git command (`push --force`, `reset --hard`, `branch -D`) without the
  user's explicit confirmation.

## Stack

- **Go**: the `advanced-go` skill of the `vaintrub` plugin.
- **Python**: 3.10 or later, with type hints. `ruff` lints and formats, not black and isort.
  `uv` manages environments.
- **TypeScript, React, Astro**: the `advanced-typescript` skill of the `vaintrub` plugin.
- **PostgreSQL**: parameterized queries and versioned migrations. Never drop a column; deprecate
  it first.
- **Kubernetes**: `kubectl` is read-only by default. Ask before `delete` or `apply` on a shared
  cluster.

## Code style

- Indent with 2 spaces in TypeScript, JavaScript, YAML and JSON, and with 4 in Python. Go uses
  tabs.
- Keep lines to 100 characters.
- In TypeScript and JavaScript, use double quotes and no semicolons, unless the project's config
  says otherwise.
- Write a comment only when the reason is not obvious from the code.

## Workflow

- Do not add features, abstractions or error handling beyond what the task needs.
- Do not add backwards-compatibility shims that the user did not ask for.
- Update existing files. Create a new file only when the task needs it.
- After a change to a UI, say so if you could not run or test it.
- Visual frontend work follows the `frontend-workflow` skill of the `vaintrub` plugin.
- Writing, research, review and planning follow the `vaintrub` plugin's skills: `clear-text`,
  `verified-research`, `independent-review`, `planning` and `writing-product-docs`.

## Security

- Keep secrets out of code. Use environment variables, direnv or 1Password.
- Never commit `.env*` files, credentials or tokens.
- Validate input only at the boundaries of a system: user input and external APIs. Trust
  internal code.
- Warn before a destructive operation on a shared system.

## Do not

- Write docstrings of several paragraphs, or long blocks of comments.
- Mention the current task, fix or caller in a code comment, such as "added for X flow".
- Validate a case that cannot happen.
- Summarize in the chat what you just changed: the diff shows it.
