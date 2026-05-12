---
name: verify-before-fix
description: Universal — don't trust verbal descriptions of bugs. Ask for screenshot / log / measurement before fixing.
---

**Rule:** When the user reports a bug verbally — "elements overlap when I scroll", "horizontal scrollbar in the middle", "this looks wrong" — ask for visual evidence (screenshot, screen recording, log output, error message) BEFORE proposing a fix.

**Why:** Verbal descriptions of bugs are ambiguous in ways that aren't obvious to either side. In the Hero Phase 2 session (calliope, 2026-05-12):

- User said "horizontal scrollbar in the middle of the screen" → I assumed page overflow → spent ~30 minutes diagnosing. Actual cause: viewport-override conflict between MCP emulation, DevTools device toolbar, and physical Chrome window. None of my code had any overflow.
- User said "not fullscreen" → I assumed vertical → added `min-height: 100svh`. User actually meant the 1240 px container looked tiny on their (assumed) 4K monitor — needed edge-to-edge fix.
- User said "everything is messed up now" → I assumed bug → screenshot showed the page was rendered at MCP-emulated size inside their natural-size browser window. Just needed to clear MCP emulation.

Each of these would have been instantly diagnosable from a screenshot, but took multiple round-trips because I diagnosed from words.

**How to apply:**

1. When user reports a visual bug:
   - First response: "Can you share a screenshot of what you see?" or "Take a screenshot and drop it on Desktop, I'll look."
   - For Mac users: `Cmd+Shift+4` (selection) or `Cmd+Shift+3` (full screen). Files land on `~/Desktop/Screenshot ....png`. Use `Read` with absolute path to view.
2. When user reports a non-visual bug (server error, broken function):
   - First response: "Can you paste the error / log output?" or "Run X and share the output."
3. Measure before fixing: when overflow / sizing is reported, run `evaluate_script` to get `window.innerWidth`, `document.scrollWidth`, `getBoundingClientRect()` on relevant elements. If numbers don't show the reported problem, the cause is somewhere else.
4. Don't speculate fixes when you can wait 60 seconds for evidence. Time-cost of the screenshot is far less than time-cost of three wrong fixes.
5. Related rules: [[read-codebase-first]] (read code BEFORE proposing), [[no-code-without-go]] (propose BEFORE editing).
