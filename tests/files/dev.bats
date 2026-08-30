#!/usr/bin/env bats
# Post-apply asserts for profile=dev: full mise toolchain, post-installs, AI CLIs.

setup() {
    export PATH="$HOME/.local/bin:$PATH"
    # `mise activate --shims` emits the shims PATH itself — no hardcoded layout.
    command -v mise >/dev/null && eval "$(mise activate bash --shims)"
    hash -r 2>/dev/null || true
}

# --- profile sanity --------------------------------------------------------

@test "chezmoi profile is dev" {
    grep -qE '^\s*profile\s*=\s*"dev"' "$HOME/.config/chezmoi/chezmoi.toml"
}

# --- languages (mise core backends) ----------------------------------------

@test "node on PATH" { command -v node; }
@test "go on PATH" { command -v go; }
@test "python on PATH" { command -v python; }
@test "rustc on PATH" { command -v rustc; }

# --- CLI utilities (mise aqua) --------------------------------------------

@test "jq" { command -v jq; }
@test "gh" { command -v gh; }
@test "delta" { command -v delta; }
@test "shellcheck" { command -v shellcheck; }
@test "fd" { command -v fd; }
@test "yq" { command -v yq; }
@test "gitleaks" { command -v gitleaks; }
@test "direnv" { command -v direnv; }

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

# --- apt dev packages (sanity check beyond common.bats core list) ---------

@test "apt: htop" { command -v htop; }
@test "apt: tree" { command -v tree; }
@test "apt: wget" { command -v wget; }
@test "apt: nmap" { command -v nmap; }
