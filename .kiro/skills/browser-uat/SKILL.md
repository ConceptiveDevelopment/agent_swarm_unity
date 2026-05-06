---
name: browser-uat
description: >
  Use when acceptance criteria require visual verification — checking that UI
  elements appear, buttons work, pages load, and no console errors occur.
  Drives a real Chrome browser via Playwright CDP. Requires Chrome running
  with --remote-debugging-port=9222.
---

# Browser UAT

## Prerequisites

Before running any browser command:
1. Check Chrome is running with debugging:
   ```bash
   curl -s http://localhost:9222/json/version | python3 -c "import json,sys; print(json.load(sys.stdin)['Browser'])" 2>/dev/null || echo "NOT RUNNING"
   ```
2. If not running, tell the human: "Chrome debug mode needed. Run: `bash .kiro/scripts/chrome-debug.sh`"
   Do NOT launch Chrome yourself — it kills the user's existing Chrome session.
3. Verify Playwright is installed:
   ```bash
   python3 -c "from playwright.sync_api import sync_playwright; print('OK')" 2>/dev/null || echo "MISSING"
   ```
   If missing: `pip install playwright && playwright install chromium`

## Target Environments

| Environment | URL | When to use |
|-------------|-----|-------------|
| Local dev | http://localhost:3000 | During development, after `npm run dev` |
| Acceptance | CloudFront acc URL | After deploy-acc, for UAT sign-off |

Always use `--tab` to target the correct tab:
```bash
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 <command>
```

## Commands Reference

| Command | Usage | Returns |
|---------|-------|---------|
| `navigate <url>` | Go to a page | Page title |
| `click "<selector>"` | Click an element | Confirmation |
| `type "<selector>" "<text>"` | Fill an input | Confirmation |
| `text "<selector>"` | Read text content | Element text |
| `elements "<selector>"` | List matching elements | Tag, id, class, text |
| `screenshot <path>` | Capture the page | Saved file path |
| `wait "<selector>"` | Wait for element visible | Confirmation |
| `wait "<selector>" --hidden` | Wait for element gone | Confirmation |
| `console [seconds]` | Capture console output | Messages with levels |
| `url` | Get current URL | URL string |
| `eval "<js>"` | Run JavaScript | Result |

## UAT Workflow

For each acceptance criterion in the issue:

### 1. Navigate to the relevant page
```bash
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 navigate http://localhost:3000/path
```

### 2. Verify UI elements exist
```bash
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 text "h1"
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 elements "button"
```

### 3. Interact and verify behavior
```bash
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 click "button.submit"
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 wait ".success-message"
```

### 4. Screenshot for evidence
```bash
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 screenshot /tmp/uat-<issue>-<step>.png
```

### 5. Check for console errors
```bash
python3 .kiro/scripts/browser-watcher.py --connect --tab localhost:3000 console 3
```

## Verdict Format

After testing all acceptance criteria, write results to the done file:

```markdown
# Browser UAT: #NNN — <title>

## Environment: localhost:3000 | acc

## Results
| Criterion | Status | Evidence |
|-----------|--------|----------|
| <criterion from issue> | ✅ PASS / ❌ FAIL | <what you observed> |

## Console Errors
None / <list errors>

## Screenshots
- /tmp/uat-NNN-1.png — <description>

## Verdict: PASS / FAIL
```

## Rules

- NEVER launch Chrome yourself — `chrome-debug.sh` kills existing sessions
- NEVER type credentials — the debug Chrome profile has persistent auth
- If a page requires auth and you're not logged in, tell the human
- If an element isn't found, try `elements "*"` to see what's on the page
- Take screenshots for every FAIL — evidence matters
- Check console errors on every page — uncaught errors are automatic FAILs
- Timeout is 5s by default — use `--timeout 10000` for slow pages
