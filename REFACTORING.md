# REFACTORING — plan of record

Working document. It plans changes; it does not describe changes already made.
Delete it when the last wave lands.

Three passes produced it. The first audited the tree: ten readers, one per
subsystem, each finding re-checked by an independent skeptic, then reviewed by a
completeness critic and by a defender arguing for the current design. The second
audited *this document* — every claim re-checked by hand, every disputed one
given a second opinion, plus reviewers for completeness, consistency and
executability. The third re-audited the rewrite, hunting two failure modes
specifically: new errors in text that had never been checked, and corrections
that got garbled on their way into the document. It found both, including a
blocking error in the SSH rewrite this document itself had introduced.

The lesson worth carrying: on this tree, a confident proposal is wrong roughly
half the time, and the failure is nearly always the same shape — a mechanism
assumed rather than run. Everything below marked "measured" or "verified" was
executed by somebody; the rest is marked as unproven.

Numbers in here are dated, not eternal. Several — trust rows, orphaned state
entries, plugin counts — are properties of the week. Re-measure at execution
time rather than trusting the figure in a sentence.

## 1. The two hypotheses that started this

### "We drifted from accepted chezmoi patterns and made it too complicated"

Half right, and the half that is right is not where it feels like it is.

The mechanisms are chezmoi-native and mostly load-bearing. `modify_` templates,
`.chezmoidata`, `.chezmoitemplates`, `.chezmoiexternal`, `create_`, `symlink_`,
the numeric script prefixes, `promptChoiceOnce`, the `.osid` composite key — each
is the documented way to do the thing it does, several verbatim from chezmoi's
own guides. The `read-source-state.pre` hook looks exotic and is the documented
answer for its job. The wrapper/library split exists so bats can drive the
installer with mocked `sudo`/`apt-get`. The ugly bits usually have a commit
behind them recording a simpler version that was tried and failed.

What is genuinely excessive:

- **A fifth of AGENTS.md is restatement, and eight of its claims are false.**
  Size is not the complaint: 502 lines against the 1,759 lines of hand-written
  config and machinery it maps — 2,868 counting the tests and CI it also
  documents — is under a third either way. (Both figures reproduce exactly:
  partition the 60 tracked files into generated 2,833, repo docs 648, tests+CI
  1,109, AI prose 1,096, and the residual is 1,759.) But ~94 of those lines tell
  the reader something they already have. Only ~14 are duplicated in the
  *literally loaded* context — §5's preamble and §11's rule bullets restate
  `ai-common.md`, which ships inside `~/.claude/CLAUDE.md`. Of the rest, ~50 are
  the tmux-external story told seven times over (1 line each in §2 twice and §3
  twice, 12 in §4, 10 in §6, and all 24 of §12) for one six-line stanza, ~19 are
  §10 restating the comment block behind `dot_zshrc`'s `# --- SSH visual tints
  ---` anchor, and the balance is §9 paraphrasing the file it describes. Wave 7
  recovers **36 lines measured**, and only if it takes both halves.
- **Vestigial machinery.** The Codex `unset` chain destroys local state on every
  apply in exchange for a guarantee the mechanism already gives.
  `.chezmoidata/secrets.yaml` is an empty map with zero consumers — verified by
  rendering the whole source with and without it: byte-identical target state.
  Eleven lines of env detection in `.chezmoi.toml.tmpl` compute a string used
  only inside a prompt's help text (`$ephemeral`, defined in the same block, is
  *not* dead — it forces the non-interactive path and CI depends on it).
- **Fail-open layout.** Any non-dot file added at the source root becomes a
  `$HOME` target unless someone remembers `.chezmoiignore` — this file included;
  see the entry added alongside it. (Dot-prefixed entries are dropped before
  `.chezmoiignore` is consulted, which is why the `.github` stanza in it is dead
  code.)

The eight false AGENTS.md claims, with their homes in this plan: §7's macOS
prerequisite paragraph (two — the Darwin branch installs no base tools, and runs
no `still_missing` check) and §8's shellcheck recipe (unrunnable) → Wave 5 step 3
and Wave 4; both halves of the `.chezmoiremove.tmpl` cell ("Empty today", and the
semantics sentence) → Wave 4; "single source of truth for … plugin lists" →
Wave 3; "source-tracked binary" (the plist is XML, as the same file says 127
lines earlier) → **done, Wave 6**; and `readonly_X → 0400`, which no wave
scheduled: `readonly_` clears write bits rather than setting a mode, so a plain
`readonly_` file lands at 0444 at this repo's 022 umask; 0400 needs
`private_readonly_`. Add that row to Wave 4 — **and its sibling trap, found on
the third pass**: `readonly_private_` is not a synonym. It lands a file literally
named `private_dot_X` at 0444, the same attribute-order bug AGENTS.md already
documents for `modify_private_`.

What is *not* excessive, despite looking it: the two-step Claude merge, the
hardcoded prereq list (a proper subset of `packages.core.*`, so rendering it
would install a firewall before chezmoi has read a source file), and
`.chezmoiignore` as a layout tool — its decisive defence is not risk but history:
`git log -- .chezmoiignore` has two commits ever, the second of which changed
only comments. Zero ignore rules have been added or removed in the repo's life,
so the maintenance debt `.chezmoiroot` exists to relieve has not occurred here.

### "The SSH-agent block in zshrc is a crutch"

It is a crutch — and the canonical replacement is worse here. Checked properly
rather than assumed, three times:

`RemoteForward /home/u/.ssh/agent.sock ${SSH_AUTH_SOCK}` — braces required, the
bare `$VAR` form is never expanded and dies with `Bad forwarding specification` —
binds its socket in **sshd**, so a second login needs `StreamLocalBindUnlink yes`
in each remote's `/etc/ssh/sshd_config`, root-owned, default `no`. The
identically-worded client-side option does not substitute: tested against a
throwaway sshd, the second login's forward fails with `remote port forwarding
failed for listen path` whether or not the client passes it. Set it server-side
and the failure inverts rather than disappears. Worse, an `${}` expansion that
resolves to nothing is a *fatal config error*: `readconf.c` ends the parse with an
unconditional `fatal()`, so with `SSH_AUTH_SOCK` unset a `Host jetson`-scoped
`RemoteForward` kills `ssh github.com` and `git ls-remote` too, exit 255 before
DNS. (The ssh_config man page's "the setting for that keyword will be ignored"
describes something the code does not do.) And dropping `ForwardAgent yes`
unsets `SSH_AUTH_SOCK` on the remote, breaking everything that reads it directly
— `ssh-add`, `docker build --ssh`, Go/Python ssh libraries, the VS Code Remote
server env.

So the block stays, and its real defects get fixed. Wave 2 carries the tested
replacement; the defects, in the order they matter:

1. **The 1Password branch has no `$SSH_CONNECTION` guard.** SSH into the Mac
   mini and the rc discards the agent you forwarded, replacing it with the
   mini's own 1Password agent — whose approval dialog appears on a screen nobody
   is sitting at. On this Mac the effect is masked for `ssh`/`git` because
   `~/.ssh/config` sets `IdentityAgent`, which overrides `SSH_AUTH_SOCK`; it
   still bites `ssh-add` and every client reading the env var directly.
2. **The relink is unconditional**, so with two concurrent logins the newer one
   repoints `~/.ssh/agent.sock` out from under the older, and the newer logout
   strands the older session's panes. The same `ln -sfn` also unlinks a socket
   *bound* at that path, orphaning whatever bound it.
   **Guard the relink on liveness, not on `-S`.** `-S` is a file-type test and it
   follows symlinks, so a socket whose owner died without unlinking it
   (OOM-killed sshd, hard power cut) still passes while nothing is listening.
   A bare `! -S $_fwd_sock` guard pins that corpse and re-pins it on every later
   login until someone runs `rm ~/.ssh/agent.sock`. Only `connect()` tells the
   two apart.
   The residual that remains is a true inversion and is accepted: with one fixed
   path and N live agents somebody always loses. First-live-wins gives the pin to
   the oldest login and strands the newest when it logs out. Neither scheme heals
   a *pane* — a new pane inherits `SSH_AUTH_SOCK=$_fwd_sock` and the rc skips the
   relink — only a fresh login heals.
3. **`ln -sfn` is unlink-then-symlink on macOS**, so the fixed path briefly does
   not exist: swapping the pin 400 times under a live connect loop produced 1,697
   ENOENT out of 66,613 `connect()`s. GNU coreutils has shipped the fix *inside*
   `ln` since 8.27 — `ln -sf` routes through `force_symlinkat`, which links to a
   temporary and renames — so on the Linux boxes this branch was written for
   there is no window at all. Do the temp-name + `mv -f` anyway, because Wave 2
   is what makes the branch live on the mini, and the mini is where the window is
   real. Keep the temp suffix per-login (`$$`): with one shared name, two racing
   logins failed 298 of 300 relinks. It buys less than it looks — a connect
   landing inside the `rename` can still fail EINVAL (128 in 130,114) — so the
   hole shrinks by an order of magnitude rather than closing, and `mv -f`
   replaces a *bound* socket exactly as `ln -sfn` does. Only the liveness guard
   prevents that; the two fixes are not interchangeable.

Dropped after checking, so the next audit does not re-file it: the unquoted `!=`
RHS at line 112 is **not** a defect. zsh makes only *literal* pattern characters
eligible for matching; characters arriving from a parameter expansion need
`GLOB_SUBST`, off by default and off here.

The other half of the mechanism — `ForwardAgent yes`, `IdentityAgent`, the LAN
host aliases — lives in an untracked `~/.ssh/config`. That split-brain is real
but it is a Gate-1 decision (14 of its 26 lines are hostnames), and tracking it
is the one change here that can destroy access. Deferred to Wave 7. Note also
that `IdentityAgent` and `SSH_AUTH_SOCK` are not one duplicated mechanism: the
env var serves `ssh-add` and non-ssh clients, `IdentityAgent` serves GUI clients
that never source a zshrc. Both are needed.

## 2. Ground rules

- `git switch -c chore/audit-remediation` (the branch name matches CI's
  `chore/**` trigger). One wave per commit; Waves 4 and 5 split into 3–4, and
  every wave accumulates on PR #45. Rollback is `git revert <sha> && chezmoi
  apply`; the floor is `git switch master && chezmoi apply`. There is no
  `pre-audit` tag, by decision: until #45 merges, master holds nothing of the
  programme except Wave 2.
  Two carve-outs. **Wave 5 steps 1 and 2 revert together or not at all** —
  reverting the gitconfig guard while the hook gate stands re-creates the failure
  the ordering exists to prevent. And **the iTerm2 plist reverts only with iTerm2
  quit**: the file is git-tracked and `git revert` does restore its bytes, but
  the app snapshots the folder at launch and compares against *that snapshot* at
  quit, so with iTerm2 running a `Copy` answer overwrites your restore. Quit
  first, revert from Terminal.app, relaunch. The `&& chezmoi apply` half is a
  no-op there — `iterm` is chezmoi-ignored and has no target.
- Acceptance criterion after every wave: **`chezmoi status` stdout is exactly
  `MM .codex/config.toml`**, run from an interactive shell with the mise shims on
  PATH. Four qualifications, or it reads as a false alarm:
  - That `MM` line is permanent. Codex rewrites the target between sessions and
    `toToml` re-serialises it alphabetically with different quoting, so actual
    can never equal target. (Note the tension with `tests/files/common.bats`,
    which asserts `chezmoi diff` is empty — see §5.)
  - `config file template has changed…` is **stderr**, exit code still 0, and is
    not part of the line count. Exactly nine commands can print it — the
    `applyArgs` path: `apply`, `status`, `diff`, `verify`, `dump`, `archive`,
    `update`, `merge-all`, and `edit` with `--apply`. Not the read-only
    commands, and — the part that surprises — not the *write* commands either:
    `add`, `re-add`, `chattr`, `forget`, `destroy` and single-file `merge` are
    all silent. Read-only vs. write is not the line; `applyArgs` is. Clear it
    with `chezmoi init`; Wave 6 re-arms it and must clear it again.
  - An ` R <script>` line appears for every script whose **rendered** bytes
    change, and clears on the next apply. "Edits a script" is not the trigger:
    script 50 embeds `sha256sum` of the mise config and both `lib/` files, so
    editing any of those three re-fires it, while a script that renders to zero
    bytes on the box you are standing on never appears at all. Measured on this
    Mac: Wave 1 → two ` R ` lines (scripts 50 and 70) plus three ` M ` lines, so
    five in total before the apply; Wave 5 → the same two; Wave 6 → **none**
    (verified by applying every Wave 6 edit in a scratch tree and re-rendering
    all seven scripts: zero changed); Wave 4 → one, and only on a headless Linux
    box, where the fonts guard takes `install-fonts.sh` from 0 bytes to 468.
  - The apply that clears those lines is not a formality — it re-runs the
    package installer.
- **Never run `chezmoi apply` on a remote box from inside your only session.**
  Open session B, apply from B, test in a new session C, leave A untouched until
  C is proven.
- Cross-wave references are by anchor text, not line number: earlier waves edit
  the same files and every absolute line number goes stale.

## 3. Waves

### Wave 0 — safety net and baseline (no functional change)

- Branch (no tag — see §2). (The tree already carries this file, its
  `.chezmoiignore` entry, and the Wave 6 trigger removal; commit those first so
  `git status` is clean.)
- Run `chezmoi init` once. It is not drift: the rendered template is
  byte-identical to the live config, and what is stale is only the recorded hash
  (`configState` holds `configTemplateContentsSHA256` = `300d782d…` against the
  template's actual `ddffa358…`). A plain `chezmoi init` rewrites the same bytes,
  writes nothing else to `$HOME`, runs no scripts and fires no hook — it reaches
  `applyArgs`, and so the source state and the pre-read hook, only under
  `--apply`.
- Ship one doc edit: README's `chezmoi update` → `chezmoi update --init`, plus
  one AGENTS.md §7 sentence. Word it precisely: **the hook's registration** is
  what lives in the rendered config and needs a re-init; the hook *script body*
  is exec'd fresh from the working tree on every source-state read and is live
  the moment you save it.
  Carry the caution, and word it by what survives in `[data]`, because the three
  cases behave differently. **All four keys cached** — the normal machine — is
  free. **The whole `[data]` table gone, non-TTY** is loud, not silent: the
  re-render dies at the `profile` prompt, `update --init` exits 1, nothing is
  touched. (Do not plan to defend that with `--promptDefaults`; it is an
  `init`-only flag.) **The silent case is the partial one**: `profile` cached but
  `name`/`email` hand-edited away, non-TTY. That run exits 0 and — because
  `dot_gitconfig.tmpl` guards on exactly the placeholder strings — drops the
  `[user]` block from `~/.gitconfig` altogether. Nothing mis-attributed is baked
  in; a machine that had a working identity silently loses it, and git does not
  then refuse to commit: with no `[user]` and no system config it committed here
  as `George Vaintrub <vaintrub@Georges-MacBook-Air.local>` with only a "Please
  check that they are accurate" notice. So the failure mode is mis-attributed
  commits, not blocked ones — and `dot_gitconfig.tmpl`'s own comment, which
  promises git "errors clearly", is wrong on a `*.local` Mac and should be fixed
  in the same edit.
- Fleet inventory: on every box, `chezmoi --version` (this Mac is 2.72.0, the
  pin is 2.70.3) and `test -e ~/.config/git/hooks/pre-push; echo $?`.
- Prove the SSH escape hatches before Wave 2 touches auth. (a) `~/.ssh/id_rsa`
  and `~/.ssh/id_fast_cloud` are on-disk keys not served by the 1Password agent,
  so `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_fast_cloud host` bypasses every
  agent question; (b) `dot_zshrc` is read only by interactive shells, so `ssh
  host /bin/sh -lc '…'` never executes the agent block; (c) `~/.zshrc_local` is
  sourced after the block and an override there wins — verified by running the
  real `dot_zshrc` under a scratch `$HOME`. It is chezmoi-**managed**
  (`create_`-seeded), not untracked: apply never rewrites it, so the override
  survives, but do not *delete* the file to retire the hatch — chezmoi holds an
  entry-state row for it, so removal adds a `DA .zshrc_local` line and makes the
  next non-interactive apply exit 1. Blank it instead.

Verify: `bats tests/unit/` green (54/54 today); `chezmoi init && chezmoi status`
→ one line, no warning; the `IdentitiesOnly` login works against each Linux box.

### Wave 1 — fresh-machine bootstrap correctness

Nothing here can regress the provisioned Mac; all of it bites only on a machine
that does not exist yet.

- **The strongest bug in the audit.** `run_onchange_after_70-install-plugins`
  never puts mise's shims on PATH. `claude` and `codex` are mise/aqua binaries;
  chezmoi `exec()`s each script as a fresh child without a login shell; script
  50's export lives in its own process. On the documented bootstrap path
  `command -v claude` fails, every plugin and MCP server is skipped with a
  stderr line, and because the script is `run_onchange_` chezmoi records the hash
  of that no-op run in `entryState` and never retries. Fix: insert script 50's
  export line verbatim at the top of 70. Keep the darwin
  `dotfiles_ensure_brew_path` block — the export busts the hash anyway.
  **No state surgery is needed to pick this up.** Editing the script changes its
  rendered bytes, which is what `run_onchange_` keys on, so the next ordinary
  apply re-fires 70 on every machine. Do **not** use `chezmoi state delete-bucket
  --bucket=scriptState`: that bucket holds `run_once_` scripts, so it re-runs
  nothing relevant and instead re-fires the 99 hint, `enable-touchid-sudo` (edits
  `/etc/pam.d`, wants sudo), `configure-iterm2` and the Linux `chsh`. The
  surgical form, for the different case of re-running 70 without editing it, is
  `chezmoi state delete --bucket=entryState
  --key="$HOME/.chezmoiscripts/70-install-plugins.sh"`. Never `delete-bucket
  --bucket=entryState` wholesale — it strips every managed file's baseline, so
  the next apply overwrites locally-edited files with no prompt.
- Delete the `{{ if lookPath "gh" }}` gate around `[settings.github]` in the mise
  config. `gh` is installed by mise later in the same apply, so the block cannot
  render on the pass that needs it, and its presence otherwise depends on which
  shell invoked chezmoi. The justification is determinism, not rate limits: on a
  fresh box `gh` is also unauthenticated, and `MISE_GITHUB_CREDENTIAL_COMMAND`
  pointing at a nonexistent command degrades silently. Do **not** generalise to
  `dot_gitconfig.tmpl`'s `gh` gate, and do not add `gh` to the prereq list —
  several target distros have no `gh` package, and the batched `apt-get install`
  would fail as a transaction and trip the hard exit.
- jq, two edits. `dot_claude/executable_statusline-command.sh` runs under
  `set -eu` and pipes to jq, so on a box without jq the script exits 127 and the
  statusline renders nothing; append `2>/dev/null || true` there — the next line
  already falls back to `$PWD`. Then move `aqua:jqlang/jq` from the `$isDev`
  block to the core block (828 K), because `tests/files/common.bats` asserts the
  Claude/Codex configs at *every* profile, so their hard dependency is core-tier
  by the repo's own decision. Guard it with a tier-gate assert on the rendered
  mise config, not with `command -v jq` — CI installs jq itself, so the obvious
  test false-passes. Scope, corrected: macOS ships `/usr/bin/jq` under SIP and
  `claude-code` is itself dev-tier, so the live exposure is a core-profile Linux
  box that got Claude Code from outside this repo.
- Sudo mode — **narrower than the earlier draft said.** Two different triples
  hide behind one sentence and they do not line up. `tty -s` is written three
  times (`hooks/ensure-prereqs.sh`, the Linux `chsh` script, the darwin
  Touch-ID script — plain `rg` shows only the first, the other two need
  `--hidden`), but only the hook's probe feeds a sudo mode; the other two gate
  skip-the-script-and-exit-0. The `dotfiles_sudo_cmd()` call sites are a
  *different* set. So factor the *probe* — `dotfiles_is_tty()` in
  `lib/common.sh` — and stop. There is no shared decision to collapse.
  **Do not wire that probe into `apt_install`/`dnf_install`.** `tty -s` tests
  stdin, but sudo reads its password from the terminal device unless given `-S`.
  The two diverge routinely — `chezmoi apply </dev/null`, or any cron or agent
  harness that pipes stdin — where `tty -s` is false while `/dev/tty` is open and
  `sudo -E` prompts and installs fine. Passing `noninteractive` there turns that
  into the entire Linux package set silently skipped with the apply still green,
  and nothing catches it: the postcondition re-check lives in the hook, and
  `lib/install-packages.sh` contains no `exit 1` at all.
  While there, fix the wrong comment in script 50 — chezmoi passes its own stdin
  to scripts (`preparedScript.cmd.Stdin = os.Stdin`, verbatim upstream), which is
  why the Touch-ID script's interactive `sudo` works, so "chezmoi child sh has no
  TTY" is false.
- New ratchet, same commit as the shims fix: a `tests/unit/repo-invariants.bats`
  case asserting every root install script that gates on a mise-installed CLI
  also exports the shims path.

Verify: `bats tests/unit/`; `chezmoi execute-template --source .
< .chezmoiscripts/run_onchange_after_70-install-plugins.sh.tmpl | sh -n`;
`chezmoi diff`; `chezmoi apply` then `chezmoi status` back to one line.

### Wave 2 — the SSH-agent block: one atomic rewrite

One commit — but not because the halfway states are unshippable. Scored against
real listening sockets and real corpses over an 80-state grid (1Password socket
present/absent × inside SSH or not × five states of `~/.ssh/agent.sock` × four of
the inherited `SSH_AUTH_SOCK`), the liveness guard **alone** leaves no state
worse than today. The restructure is where the risk sits. Scoreboard, higher is
better, today's block as the baseline:

| variant | score | worse | better |
|---|---|---|---|
| today's shipped block | 76 | — | — |
| liveness guard only | 84 | 0 | 4 |
| `-S`-guarded full rewrite | 82 | 18 | 22 |
| the earlier draft's rewrite, read literally | 90 | 14 | 24 |
| the block below | **93** | **2** | **15** |

The two "48 agent states" figures in earlier drafts of this document contradicted
each other — one said the rewrite beat today in 7 of 48, the other that it
regressed in 7 of the same 48, same number and opposite sign — and neither
reproduced. That is what a transcription failure looks like; the table above
replaces both.

The reason to land the two defects together is that they share a code path.
Today the relink sits inside the `else` of `[[ -S $_op_sock ]]`, so on any box
where 1Password runs — the mini and this MacBook both — it never executes. Any
fix to defect 1 lifts it out of that `else` and makes it live there for the first
time, and without a liveness guard that newly live path steals the pin from a
concurrent login.

**What does *not* do the lifting is reordering the branches — and that was the
blocking error in the earlier draft.** Making `[[ -S $_op_sock ]]` a bare `elif`
does not demote the 1Password agent, it *deletes* it as a fallback, because
inside SSH the `elif` is unreachable: `ssh Georges-Mac-mini.local` by hostname
misses the `mini-lan` stanza and its `ForwardAgent yes`, so nothing is forwarded,
and that shell ends with `SSH_AUTH_SOCK` unset where today it gets a working
agent. Twelve of the fourteen regressions in the literal reading are this. Relink
first under a widened gate, then choose in three arms.

The tested block, `zsh -n` clean, 93/80 above:

```zsh
# --- SSH agent ---
# Two agents can serve this shell and they are not interchangeable.
#
# A forwarded agent (ssh -A) arrives on a per-login socket — /tmp/ssh-XXXX/agent.<pid>
# under sshd < 10.1, ~/.ssh/agent/s.<host-hash>.sshd.<rand> since 10.1 — that dies
# with the login that minted it, while a tmux pane started under an earlier login
# keeps the dead path in its environment and every ssh/git call from it fails with
# "Permission denied (publickey)". Pin whatever agent is live behind one fixed name
# and export that, so panes outlive the login they were started in.
#
# 1Password's agent is this box's own, so it wins only for a local login. Under SSH
# the forwarded agent wins: otherwise sshing into the Mac mini discards the agent you
# forwarded and raises an approval dialog on a screen nobody is sitting at. (ssh and
# git are masked from that by IdentityAgent in ~/.ssh/config; ssh-add, docker build
# --ssh and every library that reads $SSH_AUTH_SOCK directly are not.)
#
# RemoteForward is the canonical replacement for all of this and was rejected: it
# binds the socket in sshd, so a second concurrent login needs StreamLocalBindUnlink
# yes in each remote's root-owned sshd_config (default no) and the identically named
# client-side option does not substitute; an ${SSH_AUTH_SOCK} that expands to nothing
# is a fatal ssh_config parse error, not a skipped keyword, so one Host-scoped
# RemoteForward kills every unrelated `ssh` with exit 255 before DNS; and without
# ForwardAgent the remote's SSH_AUTH_SOCK is never set at all.
case "$(uname -s)" in
    Darwin) _op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ;;
    Linux)  _op_sock="$HOME/.1password/agent.sock" ;;
esac
_fwd_sock="$HOME/.ssh/agent.sock"

# Liveness, not -S: -S is a file-type test and it follows symlinks, so a socket whose
# owner died without unlinking it (OOM-killed sshd, hard power cut) still passes -S
# while nothing is listening. Only connect() tells the two apart. zsocket is a
# builtin, so it costs no fork, and unlike `ssh-add -l` it cannot hang against a
# socket that accepts but never answers. Its own zmodload — the one in code() is
# inside a function and never runs at rc time.
_ssh_probe=0
zmodload zsh/net/socket 2>/dev/null && _ssh_probe=1

# Close the probe fd: an unclosed one holds a connection open inside the agent for
# the whole life of the shell.
_ssh_sock_live() {
    [[ -S $1 ]] || return 1
    (( _ssh_probe )) || return 1
    local REPLY
    zsocket "$1" 2>/dev/null || return 1
    exec {REPLY}<&-
}
# The same question on a zsh without the module: fall back to -S, which is what this
# block did before the probe existed. Asymmetric on purpose — a missing module must
# leave a corpse looking dead (so the pin is replaced), never live (so it is kept).
_ssh_sock_usable() {
    (( _ssh_probe )) && { _ssh_sock_live "$1"; return }
    [[ -S $1 ]]
}

# Gate on the pin as well as on SSH_CONNECTION: a console or serial login, a shell
# under an already-running VS Code Remote server, `docker exec`, cron — none of them
# have SSH_CONNECTION and all of them still need the pinned agent.
if [[ -n $SSH_CONNECTION || -S $_fwd_sock ]]; then
    # First live agent wins the fixed path. Repointing a live pin steals it from the
    # older login still using it, and the same relink would unlink a socket *bound*
    # there, orphaning whatever bound it.
    if ! _ssh_sock_live "$_fwd_sock" \
       && [[ $SSH_AUTH_SOCK != $_fwd_sock ]] \
       && _ssh_sock_usable "$SSH_AUTH_SOCK"; then
        [[ -d $HOME/.ssh ]] || mkdir -m 700 -p "$HOME/.ssh"
        # `ln -sfn` is unlink-then-symlink and leaves a window with no fixed path at
        # all; rename(2) has no such window.
        if ln -sfn "$SSH_AUTH_SOCK" "$_fwd_sock.$$"; then
            mv -f "$_fwd_sock.$$" "$_fwd_sock" || rm -f "$_fwd_sock.$$"
        fi
    fi
fi

if [[ -z $SSH_CONNECTION && -S $_op_sock ]]; then
    export SSH_AUTH_SOCK="$_op_sock"      # local login: this box's own agent
elif _ssh_sock_usable "$_fwd_sock"; then
    export SSH_AUTH_SOCK="$_fwd_sock"     # under SSH, or a pin left by one
elif [[ -S $_op_sock ]]; then
    export SSH_AUTH_SOCK="$_op_sock"      # remote login with nothing forwarded
fi

unfunction _ssh_sock_live _ssh_sock_usable
unset _op_sock _fwd_sock _ssh_probe
```

Four properties of that block worth stating, because each was got wrong once:

- `_fwd_sock` is assigned **above** the `if`. In today's file it is assigned
  inside the branch; leave it there and `-S $_fwd_sock` in the gate tests an
  unset variable, which zsh evaluates as false without erroring — and the exact
  case the block exists for falls through.
- The gate is widened on the **pin**, and the widening is the debatable part.
  `[[ -n $SSH_CONNECTION ]]` alone is a regression on a headless box (a console
  login with a dead inherited socket drops to an even worse socket than today).
  But `|| -S $_fwd_sock` changes the outcome in 12 of the 48 states outside the
  intended fix, while `|| ! -S $_op_sock` changes none and fixes the same case —
  worth reconsidering when the block is written, and the reason the `-S` form is
  kept above is only that it is what the tested 93-scoring block used.
- The probe answers a weaker question than `ssh-add -l`: it proves a *listener*,
  not an agent. That is the right trade — the failure being fixed is an unlinked
  corpse with no listener, `zsocket` costs no fork, and `ssh-add -l` hangs
  indefinitely against a socket that accepts and never answers (measured: still
  running after 4 s, needed SIGKILL). The fd must be closed; three unclosed
  probes left three connections open inside the agent.
- The fallback when the module is missing is **asymmetric on purpose**: a corpse
  must look dead, never live. Stating it as "treat the pin as not live and
  relink" was too loose — that would also discard a live pin.

Also here, comments only: four lines above the `[[ssh-keys]]` block in
`private_agent.toml` recording that this key is forwarded to two named LAN hosts
and must never move to `Host *`, plus a note that 1Password's approval scope can
be tightened to per-terminal-session (an app setting, and it adds a prompt per
new pane — the owner's call).

Docs last: the AGENTS.md secrets table gains a runtime-SSH-auth row (see Wave 4 —
that table ends at three rows, not four), and §4's zsh bullets gain the agent
block plus the three other sections they omit (the antidote bootstrap clone, the
PATH section, the direnv hook). Do **not** add `~/.ssh/config` to the §3
source↔target table: that table is what an agent consults to decide what to
`chezmoi add`, and an entry invites committing the LAN hostnames.

Escape hatch: this block only sets `SSH_AUTH_SOCK` *inside* an already
authenticated remote shell. The worst case is "outbound git/ssh from the remote
stops working", never "cannot log in". Recovery is one line typed in the wedged
pane, and it repairs every pane at once because they all resolve the same name at
connect time:

```zsh
for s in /tmp/ssh-*/agent.*(Nom) ~/.ssh/agent/s.*(Nom); do
  SSH_AUTH_SOCK=$s ssh-add -l >/dev/null 2>&1
  [[ $? -ne 2 ]] && { ln -sfn $s ~/.ssh/agent.sock; break }
done
```

Both globs are needed: **OpenSSH ≥ 10.1 moved forwarded agent sockets out of
`/tmp` into `~/.ssh/agent/`**, and this Mac's own sshd already does it — a live
`ssh -A` to a throwaway sshd handed back
`~/.ssh/agent/s.HK9X4ZmvyZ.sshd.KTIgYI5ZDS`, which `/tmp/ssh-*/agent.*` matches
not at all. Select on liveness, not mtime: an earlier draft's `ls -t … | head -1`
hands back the *dead* socket in exactly this scenario. Exit 2 is "cannot
connect"; exit 1 is a live agent holding no keys. If nothing answers, reconnect.
Do not park this in `~/.zshrc_local`; it is a repair, not a setting.

Verify: on the Mac console `SSH_AUTH_SOCK` unchanged and `ssh-add -l` still lists
the key; on a Linux box from session B the pinned path is exported and `ssh -T
git@github.com` authenticates; open B and C, log out of C, `ssh-add -l` in B must
still succeed; `ssh mini-lan` keeps the forwarded socket rather than the mini's
own; a non-SSH login on a headless box still resolves an agent; and **`ssh
Georges-Mac-mini.local` by hostname — the no-forward case — still gets the mini's
own agent** (this is the regression the `elif` shape caused).

### Wave 3 — decide the Codex chain, then write its docs

Six findings argue about the same twenty lines and five of them are documentation
*of* those lines. Deciding the code first collapses them.

- **Delete the `unset` chain** — `dot_codex/modify_private_config.toml:15-21`,
  which is **six** unsets: the five section unsets plus the `skills.config` strip
  that the prose must name explicitly, or "drop the rest" is undefined for it.
  The stated end state, a four-line merge, only arrives if that line goes too.
  The chain is not what keeps per-machine state out of git: `chezmoi apply`
  renders the template and writes only the target, and `chezmoi re-add` is a
  silent no-op on a `modify_` entry. Do **not** restate that as "nothing here can
  ever reach the source dir or git" — that absolute is false and was reproduced:
  `chezmoi add ~/.codex/config.toml` exits 0 with no warning, deletes the
  `modify_` template, and writes a plain `dot_codex/private_config.toml`
  byte-identical to the live file — trust rows and marketplace included — into a
  repo whose remote is public. One keystroke away, and worth a sentence in §9.
  Rendered against the live file, the chain's effect is two tables — `[projects]`
  and `[marketplaces]` — measured on 3 Sep as **four rows**: three ChatGPT-project
  trust rows plus `[marketplaces.openai-bundled]`. The project count is a
  property of the week (it was two on 2 Sep); re-measure with `diff <(chezmoi cat
  ~/.codex/config.toml) ~/.codex/config.toml` rather than trusting this sentence.
  Four of the six unsets are no-ops against today's file — `notice`, `tui`,
  `tool_suggest` and `skills.config` have no table in it — but that is a
  snapshot, not a property: fed a file containing all six, the chain strips every
  one.
  - *Trust rows are real state, and any count understates the loss.* Whether a
    row is written on open or rebuilt at launch is **disputed between two
    verifiers** — one traced a row appearing the same second a thread opened in
    that workspace and a durable `local-projects` registry that a launch does
    *not* walk; the other found a row present for a workspace with no recent
    session. Settle it before relying on either: the consequence differs (a
    workspace you leave alone stays untrusted indefinitely, versus repair at next
    launch). Both agree on the two things that matter: git is not the restore
    path, and on the CLI an untrusted directory is a hard stop — `codex exec`
    answers `Not inside a trusted directory`.
  - *The marketplace strip is smaller than claimed and its defence is refuted.*
    The four enabled bundled plugins (`browser`, `sites`, `visualize`,
    `codex-app-tools`) load from the plugin cache, not from the row: `codex debug
    prompt-input` is identical with the row present and absent. What the strip
    costs is catalog surface — `codex plugin marketplace list` drops it, and the
    desktop plugin manager (an app-server client, drivable headlessly) omits the
    marketplace *altogether*, not as an empty section, so all four plugins leave
    its installed list. The server re-reads `config.toml` per request, so an
    apply run while ChatGPT.app is open empties both lists on the next query.
    Against that, commit 40cb6d8 cites a stale-path observation — an observation,
    not a reproduction, and the live file refutes it: the strip ran and Codex put
    the row back, in its own append style at the tail of an otherwise alphabetised
    file. And a stale `source` costs nothing the strip does not: a row whose path
    no longer exists and no row at all give identical output.
    The name **is** reserved — `core-plugins/src/marketplace_policy.rs` refuses
    it from every source but one — but "so only Codex can write it" is **false**:
    the exempt source is the active home's own
    `$CODEX_HOME/.tmp/bundled-marketplaces/openai-bundled`, and adding from there
    re-creates the row verbatim, repeatably. So the strip is reversible two ways,
    by relaunch and by hand — an argument for deleting the unset, not keeping it.
    State the other half while there: line 19 drops the *whole* `marketplaces`
    table, and a marketplace you add yourself lands in it with nothing to restore
    it, so apply would delete it silently on every run.
  If a subset is kept for tidiness, keep **`notice` alone**. The earlier draft's
  "`notice` and `tool_suggest`" is wrong on the semantics: read off the binary's
  own field lists, `[tool_suggest]` holds `disabled_tools` and sits in Codex's
  config-write path next to `personality`, so it is a user choice; `[tui]` is
  `theme`, `status_line`, `terminal_title`, `animations` and the whole
  `tui.keymap.*` tree — hand-editable config, not runtime state; and
  `[[skills.config]]` selects by `path` *or* by `name`, so an entry need not
  contain an absolute path at all and the template's inline comment describes
  only some of them. Only `[notice]` is dismissals, whose loss re-shows a warning
  rather than losing a setting.
- Delete `"alwaysThinkingEnabled": true` from the Claude base — the binary's own
  schema string says absent ≡ true, so no machine changes state, and apply stops
  re-enabling thinking after a `/config` toggle-off. Keep
  `permissions.defaultMode`, `skipAutoPermissionPrompt` and `voiceEnabled`. (See
  §5 for the security cost those two carry alongside unpinned third-party
  plugins — real, and not an argument for removing them blindly.)
- **Done:** `model = "gpt-5.6-sol"` is deleted from the Codex base. It fought the
  TUI the same way `model_reasoning_effort` did, and the `save-to-dotfiles` row
  that routed `model` there now says not to. (Commit 40cb6d8 is not
  *solely* that hand-sync — its subject line is the marketplace strip — but it
  does carry it.)
- **Keep the two-step Claude merge and `deepCopy`.** State the experiment
  precisely or it cannot be reproduced, and an executor who reproduces it wrongly
  will delete working code: with a realistic input (a plugin the user disabled,
  i.e. `"sepia@sepia": false`, plus tool-written keys), the two-step merge yields
  `false`, `mergeOverwrite $existing $base` yields `true`, and dropping only the
  *second* step (`mergeOverwrite (deepCopy $base) $existing`) also yields
  `false` — it is the *other* one-liner that breaks it. `claude plugin disable -s
  user` is the only off-switch, since script 70 never uninstalls.
- Docs, after the code: retitle §9 away from "runtime-section strip"; drop the
  `ConfigEdit` maintenance obligation if the chain goes; document the
  `enabledPlugins` union and the currently-undocumented retirement procedure
  (drop the packages.yaml line **and** `claude plugin uninstall` locally **and**
  delete the `enabledPlugins` row); soften "single source of truth for … plugin
  lists" to "install baseline, not enable state"; state the permanent `MM`
  invariant. Ship a `czs()` drift-check alias in `dot_zshrc` **with** that doc
  change — but not as a bare `chezmoi status | grep -v …`: that inverts the exit
  code (1 on clean) and makes a genuine chezmoi failure indistinguishable from
  cleanliness. Write it so the filter applies to output and the status survives.
- Fix `save-to-dotfiles/SKILL.md` — the highest-value docs item, because agents
  execute it without checking. **Five** rows are wrong and a sixth is missing:
  - `~/.zshrc.local` (the target is `~/.zshrc_local`).
  - The `p10k configure` row says the wizard rewrites `dot_p10k.zsh`; it rewrites
    the *target*, so the row must end in `chezmoi re-add ~/.p10k.zsh` plus a
    commit, and the Don'ts bullet needs the same correction.
  - Both plugin rows point at generated `range` blocks instead of
    `packages.yaml`; the new rows must carry the union caveat or they teach half
    a lie.
  - **New on the third pass:** the "iTerm2 preference (simple)" row tells the
    agent to run `defaults write com.googlecode.iterm2 …`, which writes
    `~/Library/Preferences/com.googlecode.iterm2.plist` — a *different store*
    from the tracked `iterm/com.googlecode.iterm2.plist`. Nothing appears in `git
    status`, contradicting the row directly beneath it.
  - Missing: an `mcp:` row.
  The `create_`-seeded exception the earlier draft attached to the `~/.zshrc_local`
  row was **disputed** on this pass; check it before writing it as an exception,
  and mirror whatever it turns out to be in the Don'ts section so the two do not
  contradict each other. This file already rotted once (7c28413): add the
  repo-invariant that greps every source path named in the table.

Verify: `diff <(chezmoi cat ~/.codex/config.toml) ~/.codex/config.toml | grep -E
'^[<>][[:space:]]*\[(projects|marketplaces|tui|notice|tool_suggest)'` — the raw
diff is ~53 lines of re-serialisation noise, so filter it; open Codex and confirm
folder trust and theme survive an apply; `jq -r '.enabledPlugins'
~/.claude/settings.json` unchanged across an apply.

### Wave 4 — standalone docs and tests

Zero apply risk on the Mac. Group as 3–4 commits.

- AGENTS.md §7 "Hard prerequisites" is false for macOS in both directions.
  **This rewrite belongs in Wave 5 step 3's commit** — the same paragraph states
  the five-tool hard-fail that step 3 narrows. Whichever wave owns it must also
  preserve the sentence Wave 0 added to the same paragraph, and keep the framing
  explicit ("there is no base-tool loop on Darwin, this is intent") so nobody
  later "fixes the code to match the docs".
- The shellcheck recipe in §8 cannot be executed: shellcheck dies on the first
  `{{`. Replace with render-then-lint: `chezmoi execute-template --source .
  < f | shellcheck -x -s sh -`. **Four** gotchas must be in the text:
  `-s sh` is required (an OS-guarded script renders to zero bytes and bare
  shellcheck errors SC2148); `-x` is required (without it SC1091 exits 1);
  `--source .` on a machine with no config dies with `map has no entry for key
  "profile"`; and — found on the third pass — **the pipeline hides render
  failures.** shellcheck's status is the pipeline's, and `-s sh`, the very flag
  gotcha 1 mandates, is what suppresses the SC2148 an empty render would raise.
  A green run is not evidence the file rendered. Run it under `set -o pipefail`,
  or render to a temp file and lint the file.
  Do **not** write "this only lints the OS you are on" — that replacement claim
  is itself false: `[data.chezmoi] os = "darwin"` in a scratch config does
  override `.chezmoi.os` for `execute-template`, verified in both directions.
  Hold the CI-job question for Wave 7.
- Add the missing unit tests, not the missing CI legs: `brew_bundle_install` and
  `dnf_install` have zero coverage today — every mention of either in the suite
  is a stub definition, so neither body has ever run — and macOS + workstation,
  the owner's own configuration, are outside the matrix. Both tests are writable
  now against the current signatures and pass on first run.
  **Sequencing runs both ways.** If Wave 7's env-var-relay collapse is ever
  taken it renders the lists at template time, which deletes `dnf_install`
  outright and replaces `brew_bundle_install`'s inputs — both new tests break on
  that rig. Reciprocally, this wave runs first, so Wave 7's enumerated surgery is
  a census of *today's* suite: measured on that rig the collapse breaks 15
  existing tests, and these two additions take it to 17. Either accept that the
  coverage is scrapped and re-count later, or settle the relay question first.
  Do not add `workstation` to the matrix — there is no
  `tests/files/workstation.bats` and the leg goes red immediately.
- `dot_p10k.zsh` carries two hand-written blocks that `p10k configure` treats
  **differently** — do not group them. The wizard does write `INSTANT_PROMPT` and
  does ask about it, but marks "(1) Verbose" as recommended and never shows the
  current value, so `quiet` survives only if the operator presses 2; the
  three-line direnv rationale above it is dropped either way.
  `TERM_SHELL_INTEGRATION=true` appears nowhere in the wizard or in any shipped
  base config, so it vanishes with no question and no trace. Guard both settings
  *and* one distinctive line from each rationale comment with `repo-invariants`
  greps (`grep -qE '^[[:space:]]*typeset -g …'`, not `grep -qx` — both lines are
  indented), fix the stale wizard header, and replace AGENTS.md's vague guidance
  with the real procedure, which ends in `chezmoi re-add ~/.p10k.zsh`.
- Font externals: the probe misfires in both directions, and CI proves it — run
  33308622025 prints `fontconfig cache refreshed` on *both* legs, a line that
  only renders in the non-headless branch. One leg costs **65.9 MB** measured
  (10,313,480 B of TTFs + a 55,607,551 B Monaspace zip, matching content-length
  to the byte, fetched once per cache), so ~132 MB per push. Drop the SSH
  conjunct in **three** places — the external, the Linux fc-cache script, and the
  copy printed in AGENTS.md §7 — and fix the "~2 MB" comment. Counter-argument on
  the record: a Linux desktop applied from a bare tty gets no fonts *on that
  pass* and self-heals on the next apply from inside the session. (`ssh -X`
  restoring `DISPLAY` is plausible but **unproven** — it needs a second host.)
- `.chezmoiremove.tmpl`: fix "Empty today", and correct the semantics sentence to
  what chezmoi does rather than to the protective story. Reproduced on 2.72.0:
  with no entry-state record for the path, chezmoi deletes whatever is there
  silently (rc 0), and an apply that finds the path already absent records
  nothing. It pauses only when it *has* a record and the file no longer matches
  it. `--force` collapses all three to a silent delete.
  Note what that makes of the entry today, **corrected on the third pass**: this
  Mac has no such file and the state still holds the pre-audit *file* record — and
  an apply that finds the path absent leaves that record untouched, so nothing
  distinguishes "never deleted anything" from "ran and found nothing". It also
  means this Mac is **not** in the silent-delete case: with a record present and
  a mismatching file, a reappearance would stop the apply on a prompt. Keep the
  entry until Wave 6.
- Strip `calliope`, `2026-05-12` and "Hero Phase 2" from six sites across five
  `dot_claude/rules/*.md`, and generalise the component list that identifies the
  same project. Public repo. Keep every `**Why:**` narrative.
- Delete `.chezmoidata/secrets.yaml` — verified inert — but move the salvaged
  knowledge into one future-tense AGENTS.md sentence *first*. Drop the
  render-time row from **both** copies of the secrets table. **Row count:** Wave 2
  added a runtime-SSH-auth row to the same table, so the end state is **three**
  rows, and whichever wave lands second owns re-counting the "three mechanisms"
  lead-ins in AGENTS.md and README.
- Add the `readonly_X` corrections from §1 (both the 0444 fact and the
  `readonly_private_` trap) to this wave's doc commits.

### Wave 5 — installer and pre-read hook surgery

The wave that can break a fresh bootstrap. Strict intra-wave ordering.

1. **First and alone:** fix the `output "git" "--version"` shell-out in
   `dot_gitconfig.tmpl`. Do **not** use `{{- if lookPath "git" }}`: on macOS
   `/usr/bin/git` is Apple's `libxcselect` stub on the sealed system volume, so
   `lookPath` never returns empty there — at minimum it finds the stub — and the
   guard protects nothing. (On *this* Mac `lookPath "git"` returns
   `/opt/homebrew/bin/git`; the stub wins only where no brew `git` formula is
   installed, which is the common failure after a macOS major upgrade
   invalidates the CLT while Homebrew survives.) Use a form that cannot abort:
   `output "sh" "-c" "git --version 2>/dev/null || true"`, then guard the
   comparison on a non-empty result, because `semverCompare ">=2.35.0" ""` is a
   hard template error and `regexFind` returns `""` silently. Verified against
   four states: no git → `diff3`, broken stub → `diff3`, 2.50.1 → `zdiff3`,
   2.34.1 → `diff3`. Scope of today's breakage: six whole-tree commands abort
   (`status`, `diff`, `verify`, `dump`, `archive`, `apply --dry-run`), not every
   command.
2. Gate the mutating body of `hooks/ensure-prereqs.sh` on
   `case "${CHEZMOI_COMMAND:-apply}" in apply|init|update) ;; *) exit 0 ;; esac`.
   The variable is real and documented, and a probe hook confirmed the values.
   Two corrections: `upgrade` never reads source state, so listing it is inert;
   and **`chezmoi apply --dry-run` reports `CHEZMOI_COMMAND=apply`**, so a dry run
   still installs packages — either add a `CHEZMOI_ARGS` check for `--dry-run`/`-n`
   or state that dry runs deliberately still mutate. Hooks run under `--dry-run`
   by design, which is the whole reason the gate is needed.
   Must land at or after step 1. **Keep the `read-source-state.pre` registration
   — but drop the earlier reason for it, which does not survive checking.** A
   `.chezmoiscripts` before-script *can* rescue a shelling-out target template:
   content templates are rendered lazily during target-state computation, after
   every before-script, proven both ways in an isolated rig. The registration
   stays for a different reason: **archive externals are fetched during the
   source-state read**. The unconditional `.config/tmux` external means `chezmoi
   managed` itself dies on a box with no system root store (`x509: certificate
   signed by unknown authority`, verified against a self-signed server) before any
   script exists to run, and the hook installs `ca-certificates`. Also: if it were
   ever converted, it must be plain `run_before_`, never `run_once_before_`.
   Note that editing this file takes effect the moment you save it, and an
   unbalanced `case` kills `chezmoi diff` and `status` — this wave's own
   verification commands.
3. Narrow the postcondition hard-fail from five tools to `git` and `curl`
   (fatal) plus a named warning for `zsh vim tmux`, which script 50 installs on
   the same apply. Verified: `rg 'output "|lookPath' --glob '*.tmpl'` hits only
   git, delta and gh, so zsh/vim/tmux have no read-time role at all, and today a
   box that cannot install tmux is refused even a `chezmoi diff`. Add the
   invariant asserting the hook's hardcoded list is a subset of
   `packages.core.{apt,dnf}`, and own the AGENTS.md §7 rewrite moved here.
4. **Optional — and the honest recommendation is to skip it.** Replacing the
   runtime `. "{{ .chezmoi.sourceDir }}/lib/*.sh"` with `{{ include }}` + `main`
   works: `include` reads chezmoi-ignored paths (script 50 already does it for
   the hash comments), and the render passes `sh -n` and shellcheck. But the
   render is **305 lines, not 267** — the earlier figure counted only the two lib
   files and dropped the wrapper's own ~41 — so `chezmoi diff` grows from 45 to
   ~305 when the installer re-fires. And the two sentinel tests are **the only
   place the libraries are exercised by a real `sh`** (dash on Ubuntu runners);
   `grep -rn 'sh -c' tests/` returns exactly those two lines, so deleting them
   silently retires the repo's sole POSIX-dialect check, which AGENTS.md §8
   mandates. For ~10 lines of cleanup that is a bad trade.
5. `dot_gitconfig.tmpl` `lookPath` flapping — three parts, and the pager alone is
   not enough. (a) Move the template trim to the left (`{{- if … }}`) so the
   four-space indent survives; today's live `~/.gitconfig` has `pager = delta` at
   column 0 because of this. (b) Replace the pager gate with an unconditional
   guarded pager (`pager = command -v delta >/dev/null 2>&1 && delta || less`) —
   verified hermetic under two PATHs and correct under a pty in both states.
   (c) **Also unconditionalise or `$isDev`-gate the `[delta]` and `[interactive]
   diffFilter` blocks in the same edit.** The pager alone converges 1 key of 10
   and creates a mismatch that cannot happen today.
   **Correction from the third pass:** the earlier draft called this "Linux-only
   in practice, because on macOS a non-interactive apply aborts in the prereqs
   hook". False — that abort fires only when brew is *absent*. With brew present
   a non-interactive apply proceeds, and delta comes from mise in script 50,
   after the templates render, so any Mac lacking delta at render time hits the
   same first-apply mismatch. Treat the two `[credential]` blocks separately —
   d41ca8e records why they are rendered at all.
6. `| quote` → `| shellQuote` at **every** such site in both scripts, expressed
   as "every site", not as a count: script 50 has 13 today but steps 4 and 5
   rewrite those lines, and script 70 has **6 on 5 lines** (line 40 carries both
   `.name` and `.url` — converting "5 sites" leaves the MCP URL behind).
   `quote` emits Go-style double quotes, inside which `$var`, backticks and
   `$(…)` still expand. Two verified examples, kept separate because an earlier
   draft welded them into one false sentence: the plugin entry `evil$(id -u)@mkt`
   renders as `"evil$(id -u)@mkt"` and resolves to `evil501@mkt`; an MCP name
   `srv$(id -u)` renders as `"srv$(id -u)"` and resolves to `srv501`.
   **The filter swap does not close everything.** Line 33 is a bare `{{ . }}` in
   command position, and five further bare interpolations sit inside
   double-quoted `echo` strings (lines 26, 32, 41, 42, 52) — those are command
   execution, not mere expansion, and `| shellQuote` inside a surviving
   double-quoted string is inert. Each needs the whole message quoted with the
   outer double quotes removed: `echo {{ printf "claude plugin install %s failed"
   . | shellQuote }} >&2` (tested safe against four hostile shapes, including an
   embedded single quote). Do not claim this buys space-safety: the lists are
   deliberately re-split on IFS.
   Bump `.chezmoiversion` 2.70.3 → 2.72.0 **in the same commit** — `shellQuote`
   landed in exactly 2.72.0. The refusal is total (every source-state command
   including `init`, so `update --init` too), and that is the argument *for* one
   commit: shipping the edits without the pin breaks the same box messier,
   half-applied. Wave 0's census must therefore become an upgrade, not just a
   record — `chezmoi update` runs `git pull` *before* the version check, so a
   stale box pulls this commit and then locks itself out.

Verify: `bats tests/unit/`; render both install scripts through `sh -n`;
`chezmoi diff` must not invoke apt/brew (the step-2 regression test — and check
`apply --dry-run` separately); `git config --get core.pager` and a colourised
`git log`; `chezmoi --version` ≥ 2.72.0 on every box **before** pushing step 6.

### Wave 6 — macOS-local and human-in-the-loop

- **The iTerm2 trigger — done.** The profile carried an enabled `ScriptTrigger`
  with regex `vscode://[^[:space:]]+` and parameter `open \0`, unquoted and
  unanchored, and iTerm2 execs that parameter through **`/bin/sh -c`** with `\0`
  spliced in unescaped (`-[iTermBackgroundCommandRunner reallyRun]`;
  `stringByReplacingBackreference:` does no escaping). `Enable Triggers in
  Interactive Apps` defaults true, so output inside `less` and `vim` fired it
  too. It is deleted from the profile.
  The decisive fact, and the reason this cost nothing: **iTerm2 3.6.11 already
  opens a bare `vscode://…` on ⌘-click, with no trigger, no OSC 8 and no shell.**
  `iTermURLActionFactory` applies no scheme allowlist, `conservativeURLGuessing`
  compiles to `@(NO)` so a colon alone makes a string URL-like, the
  `URLCharacterSet` default contains `+ : / . - _ %` so the click range spans the
  whole `ssh-remote+<host><path>`, and the sole gate is `NSURL URLWithString:` →
  `URLForApplicationToOpenURL:`, which returns Visual Studio Code for byte-for-byte
  the string `code()` prints. The open runs through `NSWorkspace it_openURL:` into
  LaunchServices — no `/bin/sh` anywhere in that subtree. So the loss is one
  ⌘-click per invocation, and only in the plain-SSH branch; the bare-arg,
  local-Mac and `VSCODE_IPC_HOOK_CLI` branches are untouched.
  **Do not re-emit the URL as an OSC 8 hyperlink.** Against a hostile remote it
  is a downgrade, not an upgrade: OSC 8 rides the same untrusted byte stream and
  decouples the visible text from the target, so an attacker's
  `ssh-remote+<their-host>` can be painted as the word `myproject`, where a bare
  URL is what-you-see-is-what-opens. iTerm2 also tries the hypertext phase
  *first*, and it is the one path with no openability check at all. Its real
  advantage is narrow and worth recording anyway: ⌘-click routing walks Prompt →
  HypertextLink → **ExistingFile** → … → **URLLike**, so Semantic History gets
  first refusal on a plain URL, and ⌘-clicking a path component that also exists
  on the Mac can hand `/Users/…` to Semantic History instead of VS Code.
  Still to do here: **widen the percent-encoding at `dot_zshrc`'s `printf`.** It
  survives the trigger's removal for a different reason — not shell safety, URL
  correctness: `${target// /%20}` encodes spaces only, and an unencoded `#` or
  `?` truncates the path silently (`…/notes#1` parses to path `…/notes`, fragment
  `1`). Encode everything outside `[A-Za-z0-9._~/-]`. Write it as a
  per-character encoder, not a chain of `${t//x/y}` substitutions — a chain
  cannot enumerate that set, and the "% handled first" caveat exists only for the
  chain form. Three traps, each reproduced on zsh 5.9.2: `no_multibyte` makes the
  scan byte-wise (without it a UTF-8 path encodes per codepoint and comes out
  invalid); zero-pad to two hex digits (without it byte `0x09` emits `%9`); and
  `emulate -L zsh` / `localoptions` is mandatory, because options set inside a
  zsh function are global.
  Watch for one thing after upgrades: iTerm2 **3.7** (auto-update is on here)
  ships a Claude Code integration whose wizard's last step writes Enter/Exit
  workgroup triggers into every profile you pick, and it comes looking for you
  because you run `claude`. Two clicks, never automatic — but answer *Never*, or
  expect a `Triggers` array back and review it rather than calling it drift.
- iTerm2 prefs stay where they are, for the right reason. Today the GUI edit
  reaches the working tree with no *chezmoi* step — but not with no step at all,
  and the docs should say which: the only automatic writer is gated on
  `NoSyncNeverRemindPrefsChangesLostForFile_selection == 2`, and both keys are
  absent here, so the mode is the shipped `Manually`. Three things write the
  file, all deliberate: **Save Now**, the red `(!)` badge in the Settings
  titlebar, and answering **Copy** at quit. That is still the honest advantage
  over a chezmoi target: iTerm2 pushes the badge and the prompt at you, whereas
  `chezmoi re-add` is a step nothing reminds you to take, and `apply --force` (or
  a first apply with no entry state) reverts anything uncaptured. Targeting the
  domain path instead drags in 71 keys the source file does not carry, of which
  all but a handful (Sparkle update prefs, a few Apple text-input keys) are
  per-machine runtime state. Correct the register's old reason too: `re-add` does
  not *refuse* templates, it silently skips them, and this plist would be added
  as a plain `private_` file anyway.
  Each save is an atomic rewrite of the whole file, never a delta — so commit it
  alone as an `iterm:` commit, never via `git commit -am`, and quit iTerm2 before
  `chezmoi update`, which runs `git pull --autostash --rebase` in this tree.
  (Measured before the trigger removal: the committed file was a strict subset of
  the live domain — 52 keys of 123, every value identical — so a save can only
  add keys, never lose one. The removal's own diff came back clean.)
  The `.gitattributes` `diff=plist` entry plus a darwin+`lookPath plutil`-guarded
  `[diff "plist"] textconv = plutil -convert xml1 -o -` **in `dot_gitconfig.tmpl`,
  not in `.gitattributes`, and with no trailing `-`** (git passes the path as an
  argument; the stdin form errors) is a **no-op today** — the tracked plist is
  XML and plutil round-trips it byte-identically. Take it as insurance against a
  future release writing binary, not as a fix.
  **Drop the `run_once_` → `run_onchange_` rename.** Its rationale is wrong:
  `run_once_` is keyed on the rendered content hash, so a moved source dir
  already changes the baked `{{ .chezmoi.sourceDir }}` and already re-fires —
  reproduced by applying one tree from three paths. The rename adds only the
  move-back case and costs a hazard: `.chezmoi.sourceDir` is not symlink-resolved,
  so with the `~/dotfiles` back-compat symlink any apply naming the other
  spelling rewrites the pref and prints the relaunch nag (12/12 in testing).
  **And do not reach for `run_after_` as the alternative** without fixing the
  guard first: the script's `[ "$current" = "$iterm_dir" ]` is a string compare,
  not a realpath compare, so a prefixless `run_after_` inherits the same thrash in
  full, where today's `run_once_` bounds it to one fire per spelling. Resolve both
  sides through realpath, or leave `run_once_` alone — it is the safest of the
  three.
- vim-plug: pin `plug.vim` as a `type = "file"` external at a tag. Correct the
  guard: it is not a "reduction" of the existing one (`dot_vimrc:6` guards
  `plug.vim`'s own path, a different file), and `empty(glob('~/.vim/plugged'))`
  is **false once the directory exists but is empty** — exactly the half-finished
  `PlugInstall` case — so it must be `empty(glob('~/.vim/plugged/*'))`.
  Contested either way: today a box with no egress degrades softly and
  self-heals; as an external, a cold-cache apply on that box fails the whole
  apply. Do not migrate to native packages — `colorscheme dracula` fails
  *silently* there (its three-line colors file uses bare `:runtime`, which
  searches `runtimepath` only and reports no error, so `g:colors_name` is set
  while none of the 602 highlight lines in the 1,083-line `dracula_base.vim`
  ever run) and chezmoi.vim's filetype detection goes with it.
- Delete the env-detection block in `.chezmoi.toml.tmpl` — and **rewrite the
  `$hint` string to a literal in the same commit.** `$detected`, `$hasGUI` and
  `$isSSH` have exactly one consumer, that `printf`; leaving it referencing
  deleted variables is a hard template error that kills `init` (exit 1, no config
  written) on every box and reds both CI legs. Keep `$ephemeral`. Keep the
  replacement prompt string free of commas and `=` so `--promptChoice` simulation
  still works. Do **not** promote `$detected` to the `promptChoiceOnce` default —
  `--promptDefaults` returns it verbatim. Then fix the three stale doc sites,
  **and re-run `chezmoi init` on every box in the same step**: this edit re-arms
  the warning Wave 0 cleared until each machine re-inits.
- If Wave 0's `test -e ~/.config/git/hooks/pre-push` returned absent on *every*
  box, delete the `.chezmoiremove.tmpl` entry and restore the AGENTS.md cell in
  the same commit. (Absent here; the other machines are **unproven**.)

### Wave 7 — contested and structural: decide, then execute selectively

None of this is required. Stopping after Wave 6 leaves the repo strictly better
and internally consistent. Items are independent except where noted.

- **`.chezmoiroot` migration — recommendation: no.** Not because it is unproven:
  it was built in a scratch copy and works. It costs **184 source-path references
  across four doc files** (231 repo-wide) and six enumerated breakages:
  1. `include "lib/…"` resolves under `sourceDir` and dies at render, taking
     `status` and `diff` with it. (`managed` survives — it lists script entries
     without rendering them. `include "../lib/…"` does escape.)
  2. `. "{{ .chezmoi.sourceDir }}/lib/common.sh"` in scripts 50 and 70 — fix with
     `.chezmoi.workingTree`.
  3. `PrefsCustomFolder` points at `<repo>/home/iterm`, which cannot exist.
     **Corrected: this is not "invisible until a fresh Mac" — it is backwards.**
     `run_once_` re-fires when the rendered content changes, and `.chezmoiroot`
     changes the baked `sourceDir`, so the script fires on the *existing* Mac and
     writes the broken path there.
  4. `.chezmoi.toml.tmpl` left at the root is silently never read — `init` exits
     0 having written no config.
  5. `tests/unit/repo-invariants.bats` globs `dot_claude/skills/*` from the repo
     root. **Corrected: this is not a test failure, which is worse.** In the
     migrated tree the file returns `ok 1 / ok 2 / ok 3` — `find` errors, both
     sides come back empty, `diff` succeeds. CI stays green while the invariant
     stops existing.
  6. `ci.yaml`'s `hashFiles('dot_config/mise/config.toml.tmpl')`.
  Against a maintenance debt history shows has never been paid. Ship only the
  verified part: delete the dead `.github` stanza from `.chezmoiignore`, leaving
  a one-line comment. If the migration is ever taken it must be one atomic commit
  and the *final* commit of the programme.
- **The env-var relay collapse**, moved here from Wave 5 because it contradicts
  §4's register, which protects the dispatch tests it would delete. (The earlier
  draft also claimed §1 lists the relay under "not excessive" — **false**, §1's
  list is three items and the relay is not among them.) If taken, it must carry
  the full test surgery — deleting `is_workstation` alone fails 2 tests, the
  nine-var `setup()` fixture and ~12 cascade tests need rewriting, and the
  `linux_pkg_install` dispatch tests go — and it must not emit a multi-line
  Brewfile through a template variable, since `quote` escapes newlines to a
  literal `\n`. **Keep `is_dev`** regardless: four call sites, every one in an
  `if`, so a missing definition does not trip `set -eu` — the apply exits 0 with
  the macOS Brewfile silently reduced to the core list, a path nothing tests.
- **Tracking `~/.ssh/config`** — the only change that can cost access.
  Pre-migration first: copy to `~/.ssh/config.pre-chezmoi` on every machine and
  move the host blocks to `~/.ssh/config.d/hosts.conf` *before* any source edit.
  Then `private_dot_ssh/private_config.tmpl` with `Include ~/.ssh/config.d/*.conf`
  **first** (ssh_config is first-obtained-value-wins), and
  `IdentitiesOnly`/`IdentityFile`/`IdentityAgent` inside the darwin branch only —
  a headless Linux box with `IdentitiesOnly` and no `IdentityAgent` loses the
  forwarded-agent path Wave 2 just fixed. The seed file is
  `private_dot_ssh/private_config.d/create_private_hosts.conf`;
  `create_private_dot_ssh/…` is not valid chezmoi and was reproduced creating a
  literal `~/create_private_dot_ssh/` directory. Revisit Wave 2's prohibition on
  the §3 table in the same commit. Verify `ssh -G jetson-lan` before and after.
- **The AGENTS.md cut.** Must be last among docs. Fold, do not renumber. Two
  corrections from the third pass: the renumbering blast radius is **one internal
  reference plus three external files**, not one external —
  `save-to-dotfiles/SKILL.md` (§11), `dot_vimrc` (§8) and
  `.chezmoitemplates/codex-config-base.toml` (§9) all cite section numbers. And
  §12 carries **one** unique fact, not two: "no git submodules — chezmoi
  externals replace them". The font-externals row is in §3, and `$monaspaceVer`
  appears nowhere in AGENTS.md at all. Budget **36 lines measured**, and only if
  both halves land: §12 is 23, collapsing §10 onto the `# --- SSH visual tints
  ---` anchor is the other 13. Doing §12 alone leaves you seven short and looks
  like a failed edit.
  **Do not** "fix" AGENTS.md's claim that the tints are coordinated with the
  `dot_tmux.conf.local` palette — that was in the earlier draft and would replace
  a true statement with a false one: `dot_tmux.conf.local` does set seven palette
  slots, and its own comment names `colour_15`, the exact slot the zshrc SSH
  branch overrides.
- Opt-ins, each reversing or extending a recorded decision: a shellcheck CI job;
  a `macos-latest × dev` apply leg (never `macos × workstation` — those casks
  need sudo); tightening 1Password's approval scope.

## 4. Register of things deliberately NOT done

Each was proposed, checked, and rejected on evidence. ▲ marks a row corrected by
a later pass.

| Proposal | Why not |
|---|---|
| Replace the agent-socket pin with `RemoteForward` + `StreamLocalBindUnlink` | ▲ Needs root in each remote's `/etc/ssh/sshd_config`; is itself last-login-wins; unsets `SSH_AUTH_SOCK` for non-ssh consumers; and an unresolvable `${}` is a fatal parse error that kills *all* ssh on that client |
| Make the 1Password test a bare `elif` under the forwarded branch | ▲ Deletes it as a fallback rather than demoting it — inside SSH the `elif` is unreachable, so `ssh mini` without `-A` ends with no agent at all |
| Guard the relink on `! -S $_fwd_sock` | ▲ `-S` is a file-type test that follows symlinks, so it pins an unlinked corpse permanently; only a connect probe distinguishes them |
| Collapse the Claude merge to `mergeOverwrite $existing $base` | Proven non-equivalent for a user-disabled plugin. Note the *other* one-liner, `mergeOverwrite (deepCopy $base) $existing`, *is* equivalent — name which one you tested |
| Make `enabledPlugins` repo-authoritative / prune it | Silently disables plugins from private marketplaces that cannot be tracked |
| `.chezmoiroot` migration | ▲ Mechanically works; costs 184 doc references and six enumerated breakages against a maintenance debt that has never been paid |
| Convert the prereqs hook to a before-script | ▲ Not for the reason first recorded — a before-script *can* rescue a target template. It cannot rescue the source-state read, where the tmux archive external is fetched. If ever done, `run_before_`, never `run_once_before_` |
| Make `packages.yaml` the source for the hook's prereq list | ▲ Implementable (the hook can read `.chezmoidata` by relative path), rejected on merit: the hook's list is a proper *subset* of `packages.core.*` |
| Make the iTerm2 plist a chezmoi target | ▲ `re-add` silently skips templates rather than refusing them, and this file would be added plain anyway; the real cost is losing the badge-and-prompt notification channel, and 71 domain keys of runtime state |
| Re-emit the `code()` URL as an OSC 8 hyperlink | ▲ Against a hostile remote it decouples visible text from target — strictly easier to forge than a bare URL, which ⌘-click already opens with no shell |
| Rename `run_once_after_configure-iterm2` to `run_onchange_` | ▲ `run_once_` already re-fires on a changed render; the rename adds only the move-back case and thrashes under the `~/dotfiles` symlink. `run_after_` inherits the thrash unless the guard compares realpaths |
| Move `POWERLEVEL9K_INSTANT_PROMPT` out of `dot_p10k.zsh` | The wizard still writes it there; a later assignment in zshrc would make the wizard's own question a permanent no-op |
| vim native packages instead of vim-plug | ▲ Silently breaks `colorscheme dracula` (bare `:runtime` searches `runtimepath` only and reports no error) and silently loses chezmoi.vim's filetype detection |
| Delete `is_dev` from the install library | ▲ Four call sites; five unit tests fail; and because every call is in an `if`, `set -eu` never fires — the apply exits 0 with the macOS dev brew list silently emptied |
| Add `workstation` to the CI matrix | No `tests/files/workstation.bats`; the leg goes red immediately |
| Promote the detected profile to the prompt default | `--promptDefaults` returns it verbatim → GUI casks on every non-interactive apply |
| Pin the mise toolchain / add a lockfile | ▲ Half-true, moved to §5: the roll-forward story dies for the 36 `latest` declarations but not for `node = "lts"` |
| Delete the "dispatcher" unit tests as stub-testing | Each is the sole detector of a distinct wiring mutation — but see §5 for two assertions in the same suite that genuinely cannot fail |
| Delete `~/.claude`/`~/.codex` config from this repo | 17 of 60 files, 15% of lines, 8% of commits; the coupling is the shared-skill symlinks, which the invariants already police |

## 5. Backlog — real, unscheduled

Everything here is verified unless marked otherwise.

**Findings the first audit never verified.** Nine findings never reached a
skeptic. (The provenance of that count is **unproven** — the audit artifacts are
outside the repo.) Four are real and all four reproduce:

- `tests/unit/repo-invariants.bats`'s "every skill file is tracked by git" runs
  `git ls-files --others --exclude-standard --ignored`, and `--ignored`
  *restricts* the listing to ignored paths, so a skill file that is merely
  un-`git add`ed is invisible — the exact failure the file's header names. The
  fix is **not** to drop `--ignored`, which would lose the gitignore case the
  test is named for: use bare `git ls-files --others`, verified to catch both.
- `create_dot_zshrc_local` seeds a 0644 file whose commented example contains a
  plaintext `ghp_…` token shape.
- `brew link --force libpq` is unscoped and silenced.
- A false comment sits directly above the MCP list it describes
  (`.chezmoidata/packages.yaml`).

**Two bats assertions that cannot fail.** A bare `! cmd` is a dead assertion in a
bats body unless it is the final command: `set -e` does not fire on a negated
command, so the test continues and passes. Two of the repo's nine bare negations
are non-final — `tests/unit/install-packages.bats:416` and
`tests/files/core.bats:16`. Confirmed by mutation: removing the `command -v
codex` guard so `rtk init -g --codex` runs unconditionally leaves the whole suite
green.

**The flagship idempotency test is false on this Mac and cannot fail in CI.**
`tests/files/common.bats` asserts `chezmoi diff` is empty post-apply — false for
`.codex/config.toml`, the `MM` line §2 calls expected. **The CI mechanism is not
"no codex binary runs there"**, which is false: `aqua:openai/codex` sits in the
`$isDev` block, the dev leg installs it, and both script 70's `codex plugin
marketplace upgrade` and script 50's `rtk init -g --codex` execute it. It cannot
fail because both are `run_onchange` and fire only on the first of CI's two
applies; the second apply's `modify_` strips whatever they wrote, and nothing
runs codex between that apply and the bats run. Excluding the file states the
real invariant but blinds the repo's only convergence test to drift in the one
file whose merge logic must track upstream — pair the exclusion with a narrower
assert (that the runtime sections are absent from the *rendered* target) rather
than dropping the file. Related: `chezmoi state dump` holds **8 orphaned
`scriptState` rows across 3 script names**, not 3 rows.

**The second security finding: unpinned third-party code into an auto-approving
agent.** Script 70 runs `claude plugin install --scope user` + `plugin update`
over 8 plugins, 3 from personal third-party marketplaces, unpinned at HEAD,
re-pulled whenever the list changes — into an agent whose tracked base sets
`permissions.defaultMode: "auto"` and `skipAutoPermissionPrompt: true`. Neither
half is wrong alone; together they are an unattended-execution path.

**Pinning discipline is applied to 2 of 8 remote dependencies** — gpakosz/.tmux
by commit SHA and Monaspace Neon by release tag, both in
`.chezmoiexternal.toml.tmpl`. Unpinned: `git clone --depth=1 antidote` at
*interactive shell startup* on every machine, plus 9 zsh plugins from HEAD;
Homebrew's `install.sh` fetched from a `HEAD` ref and executed via command
substitution; `https://mise.run` staged to a temp file and run (deliberately
**not** piped — the comment says why, and an earlier draft got this wrong); the
four MesloLGS fonts from a `master` ref; and `plug.vim` from `master` at vim
startup. chezmoi externals support `checksum.sha256`.
The antidote failure mode is **worse than "sources a file that was never
written"**: the `>${zsh_plugins}.zsh` redirect creates the file before command
lookup fails, so `source` succeeds with rc 0 and the shell starts silently
plugin-free — and because that empty file is now newer than `.zsh_plugins.txt`,
the `-nt` guard means it is **never regenerated**, even after the network comes
back and antidote clones successfully. Verified in a scratch `$HOME`.

**`node = "lts"` moves on its own.** 36 of the 38 mise declarations are `latest`,
where an existing install satisfies the request and a re-fire installs nothing.
`lts` is a moving alias re-resolved remotely: with node 22 installed, mise
reports `node@24.20.0 ⇢ would install`. Node 26 becomes LTS on **2026-10-28**,
and Wave 1 edits the mise config, which busts the hash and re-fires script 50 —
so the first apply after that date carries a silent major-version move as a side
effect of an unrelated refactor. `mise lock --global` also closes the
"same config text, different versions a month apart" gap — **but only after the
lockfile it writes (`~/.config/mise/mise.lock`) is itself chezmoi-managed**;
untracked, it pins one machine and no other. Decided 2026-10-25: the 24 → 26
move is accepted and `lts` stays unpinned; the lockfile question stays open.

**`chezmoi apply` is not convergent when it half-fails.** Every install path
turns failure into a stderr line and returns 0, after which the wrapper exits 0
and chezmoi records the `run_onchange` hash as satisfied. A first apply that
fails partway is indistinguishable from success and is never retried until an
unrelated edit changes the script's bytes.

**Codex's global instructions point at a path that resolves nowhere.**
`dot_codex/AGENTS.md.tmpl` tells every Codex session to read the rule bodies
under `dot_claude/rules/` — a *source-state* path that resolves to
`<cwd>/dot_claude/rules/` in any other project. The live files are at
`~/.claude/rules/`. The same file gets it right two lines later with an absolute
`{{ .chezmoi.homeDir }}` path. Related: Claude's `@RTK.md` import points at a
file `rtk init` only writes at dev/workstation.

**The 1Password vault-name bug was never swept.** Three sites assume a vault
named `Personal`: `lib/install-packages.sh`'s rate-limit warning, the unit test
that pins it, and — in a form no `op://` grep finds — the *first-apply terminal
hint*'s `op item create --vault Personal`. 1Password's default personal vault has
been named `Private` since ~2021. **Settle it on this account first** with `op
vault list --format=json | jq -r '.[].name'`: the point of 3d29ca6 was that a
name matching nothing fails silently, and guessing `Private` from the documented
default repeats the mistake in the other direction.

**"The apply PATH" is defined in three incompatible places** — appended in
`dot_zshrc`, prepended in script 50, prepended again in CI with a comment
explaining that otherwise `lookPath "delta"` renders false. But do **not** reach
for the obvious `dotfiles_ensure_tool_path()` helper in `lib/common.sh`: script
50 embeds a `common-hash` so lib edits re-fire it and script 70 does not, so a
later change to the shared helper would silently never reach 70 — re-creating the
Wave 1 bug one indirection deeper. Fix it in the two scripts, or give 70 a hash
line first.

**`alias zshconfig="vim ~/.zshrc"` teaches the anti-pattern the repo forbids** —
editing the chezmoi target, which the next apply reverts. `chezmoi edit
~/.zshrc`. (Correction: only AGENTS.md carries the general prohibition;
`ai-common.md` is scoped to `~/.claude/` and `~/.codex/`, and the README never
forbids editing a target at all — so the rule is stated once, not three times.)
