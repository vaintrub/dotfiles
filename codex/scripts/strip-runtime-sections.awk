# Git clean filter for ~/.codex/config.toml.
#
# Codex auto-mutates several sections of config.toml at runtime; without
# this filter every `codex` invocation that adds a new trust prompt or
# decrements a NUX counter would dirty the working tree.
#
# Canonical list of mutable sections lives in the `ConfigEdit` enum in
#   https://github.com/openai/codex (codex-rs/core/src/config/edit.rs)
# Strip targets here mirror that enum's runtime-only variants:
#   [projects."<path>"]           — auto-added on each "trust this dir" prompt
#   [notice] / [notice.*]         — one-time UI dismissals + migration prompts
#   [tui.*]                       — theme, keymap, nux counters
#   [tool_suggest]                — disabled_tools list (toggled via UI)
#   windows_wsl_setup_acknowledged (top-level key, Windows-WSL only)
#
# User-curated sections kept as-is: model, personality, model_reasoning_effort,
# [plugins.*], [profiles.*], [permissions.*], [model_providers.*], [agents],
# [hooks], [analytics], [memories], [otel].
#
# Note: [mcp_servers.*] is NOT stripped here. OAuth-backed entries get
# rewritten by `codex mcp login` (via ReplaceMcpServers), but command-based
# entries are perfectly portable. Revisit when MCP usage grows.
#
# TODO: drop this filter when openai/codex#15433 lands.

BEGIN { skip = 0 }

# Section headers: enter skip-mode for runtime-mutated tables.
/^\[/ { skip = ($0 ~ /^\[(projects\.|notice\]|notice\.|tui\.|tool_suggest\])/) ? 1 : 0 }

# Top-level runtime key (rare, Windows-WSL only).
/^windows_wsl_setup_acknowledged[[:space:]]*=/ { next }

!skip { print }
