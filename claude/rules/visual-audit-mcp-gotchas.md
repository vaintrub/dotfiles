---
name: visual-audit-mcp-gotchas
description: Frontend — three-layer viewport conflicts, resize_page vs emulate, screenshot timeout recipe, preview-server hard-refresh requirement.
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.astro"
  - "**/*.svelte"
  - "**/*.vue"
  - "**/*.html"
  - "**/*.css"
  - "**/*.scss"
  - "**/*.sass"
---

**Rule:** When using `chrome-devtools` MCP for visual audits, expect these specific failure modes and apply the workarounds proactively.

**Why:** Each of these caused ~30+ minutes of confusion during the Hero Phase 2 session (calliope, 2026-05-12). They are reproducible and predictable — adding them to memory means the next visual-audit session avoids them.

## Gotcha 1 — Three layers of viewport override can silently conflict

| Layer | Source | What it does |
|---|---|---|
| 1. Physical window | User drags Chrome edges | Sets the actual outer dimensions |
| 2. DevTools device toolbar | User clicks "Toggle device toolbar" icon (📱) | Overrides viewport to a preset or "responsive" |
| 3. MCP emulation | `mcp__chrome-devtools__emulate { viewport }` | Overrides via CDP `Emulation.setDeviceMetricsOverride` |

When these disagree: page renders at one size, shows in a different-sized window. Looks like "content rectangle in top-left of empty browser canvas" — looks like a layout bug; isn't.

**Workaround:** Clear MCP emulation before asking the user to view their browser:

```ts
mcp__chrome-devtools__emulate({ viewport: '' });
```

And ask user to close the DevTools device toolbar if it's on.

## Gotcha 2 — `resize_page` is capped by physical host screen

On a 1710-wide laptop, `resize_page(2560, 1440)` returns `Restore window to normal state`. For wider viewport tests (4K / 5K) use **`emulate`** instead:

```ts
mcp__chrome-devtools__emulate({ viewport: '2560x1440x1' });
mcp__chrome-devtools__emulate({ viewport: '375x812x3,mobile,touch' });
```

## Gotcha 3 — `take_screenshot` times out on pages with running animations

First screenshot works, second/third times out, then everything hangs. Cause: autoplay videos + infinite CSS animations occupy the Chrome capture pipeline.

**Workaround:** Pause videos AND cancel all animations + transitions BEFORE screenshot. Use JPEG (not PNG) at quality 75-85, `fullPage: false`.

```ts
mcp__chrome-devtools__evaluate_script({
  function: `() => {
    document.querySelectorAll('video').forEach(v => v.pause());
    document.getAnimations().forEach(a => a.cancel());
    const s = document.createElement('style');
    s.textContent = '*{animation:none!important;transition:none!important}';
    document.head.appendChild(s);
  }`,
});
mcp__chrome-devtools__take_screenshot({
  filePath: '/abs/path/screenshot.jpeg',
  format: 'jpeg', quality: 80, fullPage: false,
});
```

If still times out: `close_page` → `new_page` → re-emulate → navigate → re-pause → re-screenshot.

## Gotcha 4 — "Chrome is being controlled" banner eats ~25 px

When MCP is connected, Chrome shows a yellow banner: "Chrome is being controlled by automated test software". This banner is ~25 px tall and reduces effective viewport height. A `100svh` hero will appear ~25 px shorter than expected in user's screenshot. Tell the user this is normal, not a bug.

## Gotcha 5 — Preview server (`pnpm preview`, `astro preview`) serves static files

After any rebuild, the browser caches HTML/CSS. The user sees yesterday's layout while you think you just fixed the issue. **Always instruct user to `Cmd+Shift+R` after telling them to look.**

## Gotcha 6 — Don't assume monitor size from "I have a 4K"

"4K monitor" can mean:
- Fullscreen Chrome on a 5120 × 2880 iMac → viewport 5120
- Maximized on a 3840 × 2160 4K external → viewport 3840
- MacBook Pro Retina at default scaling → **1710 × 1107** (physical 4K backing, logical 1710)
- Chrome at half-screen width → 855 × 1107

**Always run `evaluate_script` to read `window.innerWidth`** before fixing layout based on viewport assumptions.

```ts
mcp__chrome-devtools__evaluate_script({
  function: `() => ({
    w: window.innerWidth,
    h: window.innerHeight,
    dpr: window.devicePixelRatio,
    screen: { w: window.screen.width, h: window.screen.height },
  })`,
});
```

## Related rules

- [[verify-before-fix]] — visual evidence (screenshot) before fix.
- [[frontend-spec-first-workflow]] — full per-block workflow including visual-audit phase.
- Each project may also have its own `notes/research/visual-audit-workflow-lessons.md` with project-specific gotchas.
