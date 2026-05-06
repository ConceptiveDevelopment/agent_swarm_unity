#!/usr/bin/env python3
"""
Browser control and console watcher via Playwright CDP.

Connects to an existing Chrome (--remote-debugging-port=9222) and lets an
AI agent or human act as a user: navigate, click, type, screenshot, read
elements, and capture console messages.

Usage:
    # One-shot commands (agent-friendly — call from shell, get result, exit):
    python3 browser-watcher.py --connect navigate https://example.com
    python3 browser-watcher.py --connect click "button.submit"
    python3 browser-watcher.py --connect type "#email" "user@example.com"
    python3 browser-watcher.py --connect screenshot /tmp/page.png
    python3 browser-watcher.py --connect text "h1"
    python3 browser-watcher.py --connect html ".error-message"
    python3 browser-watcher.py --connect wait ".loading" --hidden
    python3 browser-watcher.py --connect console
    python3 browser-watcher.py --connect elements "button"
    python3 browser-watcher.py --connect url
    python3 browser-watcher.py --connect eval "document.title"

    # Watch mode (long-running, streams console output):
    python3 browser-watcher.py --connect watch --tab myapp --log /tmp/console.log

    # Tab selection:
    python3 browser-watcher.py --connect --tab localhost:3000 screenshot /tmp/page.png

Prerequisites:
    pip install playwright && playwright install chromium
    bash scripts/chrome-debug.sh   # launch Chrome with debugging
"""

import argparse
import json
import sys
import os
import signal
from datetime import datetime


def get_page(browser, tab_filter=None):
    """Get the first matching page from the browser."""
    for ctx in browser.contexts:
        for page in ctx.pages:
            if tab_filter and tab_filter not in page.url:
                continue
            return page
    # No match — return first page
    for ctx in browser.contexts:
        if ctx.pages:
            return ctx.pages[0]
    return None


def cmd_navigate(page, args):
    url = args.action_args[0] if args.action_args else None
    if not url:
        print("❌ Usage: navigate <url>")
        return 1
    page.goto(url, wait_until="domcontentloaded")
    print(f"✅ Navigated to {page.url}")
    print(f"   Title: {page.title()}")
    return 0


def cmd_click(page, args):
    selector = args.action_args[0] if args.action_args else None
    if not selector:
        print("❌ Usage: click <selector>")
        return 1
    page.click(selector, timeout=args.timeout)
    print(f"✅ Clicked: {selector}")
    return 0


def cmd_type(page, args):
    if len(args.action_args) < 2:
        print("❌ Usage: type <selector> <text>")
        return 1
    selector, text = args.action_args[0], " ".join(args.action_args[1:])
    page.fill(selector, text, timeout=args.timeout)
    print(f"✅ Typed into {selector}: {text}")
    return 0


def cmd_screenshot(page, args):
    path = args.action_args[0] if args.action_args else "/tmp/screenshot.png"
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    page.screenshot(path=path, full_page=args.full_page)
    print(f"✅ Screenshot saved: {path}")
    return 0


def cmd_text(page, args):
    selector = args.action_args[0] if args.action_args else "body"
    el = page.query_selector(selector)
    if not el:
        print(f"❌ No element found: {selector}")
        return 1
    print(el.text_content())
    return 0


def cmd_html(page, args):
    selector = args.action_args[0] if args.action_args else "body"
    el = page.query_selector(selector)
    if not el:
        print(f"❌ No element found: {selector}")
        return 1
    print(el.inner_html())
    return 0


def cmd_elements(page, args):
    selector = args.action_args[0] if args.action_args else "*"
    els = page.query_selector_all(selector)
    print(f"Found {len(els)} element(s) matching '{selector}':")
    for i, el in enumerate(els[:20]):
        tag = el.evaluate("e => e.tagName.toLowerCase()")
        text = (el.text_content() or "").strip()[:60]
        attrs = el.evaluate("e => { const a = {}; for (const attr of e.attributes) a[attr.name] = attr.value; return a; }")
        id_str = f" id={attrs['id']}" if attrs.get("id") else ""
        cls_str = f" class={attrs['class']}" if attrs.get("class") else ""
        print(f"  [{i}] <{tag}{id_str}{cls_str}> {text}")
    if len(els) > 20:
        print(f"  ... and {len(els) - 20} more")
    return 0


def cmd_wait(page, args):
    selector = args.action_args[0] if args.action_args else None
    if not selector:
        print("❌ Usage: wait <selector> [--hidden]")
        return 1
    state = "hidden" if args.hidden else "visible"
    page.wait_for_selector(selector, state=state, timeout=args.timeout)
    print(f"✅ Element {selector} is {state}")
    return 0


def cmd_url(page, args):
    print(page.url)
    return 0


def cmd_eval(page, args):
    expr = " ".join(args.action_args) if args.action_args else None
    if not expr:
        print("❌ Usage: eval <javascript>")
        return 1
    result = page.evaluate(expr)
    if isinstance(result, (dict, list)):
        print(json.dumps(result, indent=2))
    else:
        print(result)
    return 0


def cmd_console(page, args):
    """Capture console messages for a duration then exit."""
    duration = int(args.action_args[0]) if args.action_args else 5
    messages = []

    def on_msg(msg):
        messages.append({"type": msg.type, "text": msg.text})

    def on_err(err):
        messages.append({"type": "error", "text": f"Uncaught: {err.message}"})

    page.on("console", on_msg)
    page.on("pageerror", on_err)
    page.wait_for_timeout(duration * 1000)
    page.remove_listener("console", on_msg)
    page.remove_listener("pageerror", on_err)

    if not messages:
        print("No console messages captured.")
    else:
        for m in messages:
            icons = {"error": "❌", "warning": "⚠️", "info": "ℹ️", "log": "  "}
            icon = icons.get(m["type"], "  ")
            print(f"{icon} [{m['type']}] {m['text']}")
    return 0


def cmd_watch(page, args):
    """Long-running watch mode — streams console output."""
    log_file = None
    if args.log:
        os.makedirs(os.path.dirname(args.log) or ".", exist_ok=True)
        log_file = open(args.log, "a")

    def emit(level, text):
        ts = datetime.now().strftime("%H:%M:%S")
        icons = {"error": "❌", "warning": "⚠️", "info": "ℹ️", "log": "  ", "debug": "🔍"}
        icon = icons.get(level, "  ")
        line = f"[{ts}] {icon} [{level}] {text}"
        print(line)
        if log_file:
            log_file.write(line + "\n")
            log_file.flush()
        if args.notify and level == "error" and sys.platform == "darwin":
            safe = text[:80].replace('"', '\\"').replace("'", "")
            os.system(f'osascript -e \'display notification "{safe}" with title "🐝 Browser Error"\'')

    page.on("console", lambda msg: emit(msg.type, msg.text))
    page.on("pageerror", lambda err: emit("error", f"Uncaught: {err.message}"))

    print(f"👁️  Watching: {page.url}")
    if args.log:
        print(f"📝 Logging to: {args.log}")
    print("Ctrl+C to stop\n")

    try:
        signal.pause()
    except (KeyboardInterrupt, AttributeError):
        try:
            while True:
                import time; time.sleep(1)
        except KeyboardInterrupt:
            pass

    if log_file:
        log_file.close()
    return 0


COMMANDS = {
    "navigate": cmd_navigate,
    "click": cmd_click,
    "type": cmd_type,
    "screenshot": cmd_screenshot,
    "text": cmd_text,
    "html": cmd_html,
    "elements": cmd_elements,
    "wait": cmd_wait,
    "url": cmd_url,
    "eval": cmd_eval,
    "console": cmd_console,
    "watch": cmd_watch,
}


def main():
    parser = argparse.ArgumentParser(
        description="Browser control and console watcher via Playwright CDP",
        epilog="Commands: " + ", ".join(COMMANDS.keys()),
    )
    parser.add_argument("action", nargs="?", choices=list(COMMANDS.keys()), help="Action to perform")
    parser.add_argument("action_args", nargs="*", help="Arguments for the action")
    parser.add_argument("--connect", action="store_true", help="Connect to existing Chrome")
    parser.add_argument("--port", type=int, default=9222, help="Chrome debugging port (default: 9222)")
    parser.add_argument("--tab", type=str, help="Filter: select tab whose URL contains this string")
    parser.add_argument("--timeout", type=int, default=5000, help="Action timeout in ms (default: 5000)")
    parser.add_argument("--log", type=str, help="Log file for watch mode")
    parser.add_argument("--notify", action="store_true", help="macOS notification on errors (watch mode)")
    parser.add_argument("--hidden", action="store_true", help="Wait for element to be hidden (wait command)")
    parser.add_argument("--full-page", action="store_true", help="Full page screenshot")

    args = parser.parse_args()

    if not args.action:
        parser.print_help()
        sys.exit(1)

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("❌ Playwright not installed. Run: pip install playwright && playwright install chromium")
        sys.exit(1)

    with sync_playwright() as p:
        if args.connect:
            try:
                browser = p.chromium.connect_over_cdp(f"http://localhost:{args.port}")
            except Exception as e:
                print(f"❌ Cannot connect to Chrome on port {args.port}.")
                print(f"   Run: bash scripts/chrome-debug.sh")
                print(f"   Error: {e}")
                sys.exit(1)
        else:
            browser = p.chromium.launch(headless=False)
            page = browser.new_page()
            if args.action == "navigate" and args.action_args:
                pass  # navigate command will handle it
            else:
                page.goto("about:blank")

        page = get_page(browser, args.tab)
        if not page:
            print("❌ No page found" + (f" matching '{args.tab}'" if args.tab else ""))
            sys.exit(1)

        try:
            rc = COMMANDS[args.action](page, args)
        except Exception as e:
            print(f"❌ {e}")
            rc = 1

        if not args.connect:
            browser.close()

    sys.exit(rc or 0)


if __name__ == "__main__":
    main()
