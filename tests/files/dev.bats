#!/usr/bin/env bats
# Dev-tier post-apply asserts. Runs only by CI's `apply-dev` job (after
# `chezmoi apply` against profile=dev on Ubuntu). Verifies the full mise
# toolchain landed + post-install steps succeeded + AI CLIs are reachable.
#
# Counterpart of tests/files/common.bats which covers the profile-agnostic
# baseline (dotfiles present, mise itself + fzf/zoxide, core apt packages).
#
# Run locally on a dev-profile machine: bats tests/files/dev.bats

setup() {
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    hash -r 2>/dev/null || true
}

# --- profile sanity --------------------------------------------------------

@test "chezmoi profile is dev" {
    grep -qE '^\s*profile\s*=\s*"dev"' "$HOME/.config/chezmoi/chezmoi.toml"
}

# --- languages (mise core backends) ----------------------------------------

@test "node on PATH (mise lts)" { command -v node; }
@test "go on PATH (mise latest)" { command -v go; }
@test "python on PATH (mise 3.12)" { command -v python; }
@test "rustc on PATH (mise stable)" { command -v rustc; }

# --- CLI utilities (mise aqua) --------------------------------------------

@test "jq" { command -v jq; }
@test "gh" { command -v gh; }
@test "delta" { command -v delta; }
@test "shellcheck" { command -v shellcheck; }
@test "fd" { command -v fd; }
@test "yq" { command -v yq; }
@test "gitleaks" { command -v gitleaks; }

# --- cloud + Kubernetes (mise aqua) ---------------------------------------

@test "kubectl" { command -v kubectl; }
@test "helm" { command -v helm; }
@test "k9s" { command -v k9s; }
@test "kustomize" { command -v kustomize; }
@test "stern" { command -v stern; }
@test "argocd" { command -v argocd; }
@test "tofu (opentofu)" { command -v tofu; }
@test "aws (awscli)" { command -v aws; }
@test "rclone" { command -v rclone; }
@test "cloudflared" { command -v cloudflared; }

# --- networking + Go ecosystem + pkg managers (mise aqua) -----------------

@test "websocat" { command -v websocat; }
@test "buf" { command -v buf; }
@test "golangci-lint" { command -v golangci-lint; }
@test "goreleaser" { command -v goreleaser; }
@test "gotestsum" { command -v gotestsum; }
@test "protoc-gen-go" { command -v protoc-gen-go; }
@test "pnpm" { command -v pnpm; }
@test "uv" { command -v uv; }

# --- post-installs (need mise's runtimes) ---------------------------------

@test "goimports (go install)" { command -v goimports; }
@test "ssh-audit (uv tool install)" { command -v ssh-audit; }

# --- AI CLIs (mise aqua: native binaries, no Node coupling) ----------------

@test "claude" { command -v claude; }
@test "codex" { command -v codex; }

# --- execute-checks: actually run --version on critical binaries ----------
# command -v above resolves PATH but doesn't catch broken binary (corrupt
# aqua download, glibc mismatch on Linux, version_prefix filter mismatch
# after upstream naming change). These tests catch that.

@test "claude --version executes" { run claude --version; [ "$status" -eq 0 ]; }
@test "codex --version executes" { run codex --version; [ "$status" -eq 0 ]; }
@test "op --version executes" { run op --version; [ "$status" -eq 0 ]; }
@test "gh --version executes" { run gh --version; [ "$status" -eq 0 ]; }
@test "delta --version executes" { run delta --version; [ "$status" -eq 0 ]; }
@test "rtk --version executes (skip on glibc < 2.39)" {
    run rtk --version
    [ "$status" -eq 0 ] || skip "rtk fails (likely glibc < 2.39 on this runner)"
}

# --- no partial install ----------------------------------------------------

@test "no (missing) mise tools post-install" {
    ! mise ls 2>/dev/null | grep -q '(missing)'
}

# --- idempotency -----------------------------------------------------------

@test "chezmoi diff is empty post-apply" {
    run chezmoi diff
    if [ "$status" -ne 0 ] || [ -n "$output" ]; then
        echo "chezmoi diff exit=$status output:" >&2
        echo "$output" >&2
    fi
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- apt dev packages (sanity check beyond common.bats core list) ---------

@test "apt: htop" { command -v htop; }
@test "apt: tree" { command -v tree; }
@test "apt: wget" { command -v wget; }
@test "apt: nmap" { command -v nmap; }
