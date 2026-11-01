"""Run against a debug export served locally; no third-party JS or runtime telemetry service."""
import argparse
import json
from pathlib import Path

from playwright.sync_api import sync_playwright


def run(url: str, executable: str):
    output = Path("test-results")
    output.mkdir(exist_ok=True)
    errors = []
    results = []

    def record(message):
        results.append(message)
        print("PASS:", message, flush=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=executable,
            headless=True,
            args=["--no-sandbox", "--enable-unsafe-swiftshader", "--use-angle=swiftshader"],
        )
        context = browser.new_context(viewport={"width": 390, "height": 844}, has_touch=True, device_scale_factor=2)
        page = context.new_page()
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.goto(url, wait_until="networkidle")
        page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)

        def snap():
            return page.evaluate("window.snowSnapshot")

        def position(x, y):
            box = page.locator("canvas").bounding_box()
            return {"x": box["x"] + x / 360 * box["width"], "y": box["y"] + y / 640 * box["height"]}

        def click(x, y):
            pos = position(x, y)
            page.mouse.click(pos["x"], pos["y"])

        page.screenshot(path=str(output / "browser-title.png"))
        click(180, 323)
        page.wait_for_function("window.snowSnapshot?.mode === 'play'")
        first = snap()
        cdp = context.new_cdp_session(page)
        points = [dict(position(116, 596), id=0), dict(position(301, 593), id=1)]
        cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": points})
        page.wait_for_function("window.snowSnapshot.touches === 2 && window.snowSnapshot.blowing && window.snowSnapshot.x > 195")
        assert snap()["charge"] < first["charge"]
        cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        page.wait_for_function("window.snowSnapshot.touches === 0 && !window.snowSnapshot.blowing")
        record("simultaneous real browser touches move and blow; release clears both")

        page.keyboard.down("a")
        page.wait_for_function("window.snowSnapshot.x < 185")
        page.keyboard.up("a")
        page.keyboard.down("Space")
        page.wait_for_function("window.snowSnapshot.rescued > 0", timeout=20000)
        page.screenshot(path=str(output / "browser-gameplay.png"))
        page.keyboard.up("Space")
        record("keyboard movement and actual gust-to-canopy rescue")

        page.keyboard.press("Escape")
        page.wait_for_function("window.snowSnapshot.mode === 'paused'")
        frozen = snap()["time"]
        page.wait_for_timeout(500)
        assert snap()["time"] == frozen
        for width, height in [(360, 640), (390, 844), (360, 840), (768, 1024), (1280, 720)]:
            page.set_viewport_size({"width": width, "height": height})
            page.wait_for_timeout(300)
            box = page.locator("canvas").bounding_box()
            assert abs(box["width"] / box["height"] - 9 / 16) < 0.002
            assert box["x"] >= -0.5 and box["y"] >= -0.5
            assert box["x"] + box["width"] <= width + 1
            assert box["y"] + box["height"] <= height + 1
            assert snap()["logical_size"] == [360, 640], snap()
        page.screenshot(path=str(output / "browser-wide.png"))
        record("pause freezes time; five aspect ratios preserve full 360×640 simulation")

        page.set_viewport_size({"width": 390, "height": 844})
        page.evaluate("document.body.style.padding = '24px 0 34px'; window.dispatchEvent(new Event('resize'))")
        page.wait_for_timeout(300)
        box = page.locator("canvas").bounding_box()
        assert box["y"] >= 24 and box["y"] + box["height"] <= 810.5
        record("simulated top/bottom safe-area padding retains the whole playfield")
        page.evaluate("document.body.style.padding = ''; window.dispatchEvent(new Event('resize'))")
        page.keyboard.press("Escape")
        page.wait_for_function("window.snowSnapshot.mode === 'play'")
        page.wait_for_function("window.snowSnapshot.mode === 'workshop'", timeout=45000)
        assert snap()["points"] == 1
        page.screenshot(path=str(output / "browser-workshop.png"))
        click(180, 244)
        page.wait_for_function("window.snowSnapshot.tiers[1] === 1 && window.snowSnapshot.points === 0")
        click(235, 485)
        page.wait_for_function("window.snowSnapshot.mode === 'play' && window.snowSnapshot.day === 2")
        assert snap()["tiers"] == [0, 1, 0]
        record("real day completion, workshop purchase and upgrade carryover")

        page.wait_for_function("window.snowSnapshot.mode === 'lost'", timeout=60000)
        page.wait_for_timeout(4500)
        page.screenshot(path=str(output / "browser-winter-loss.png"))
        record("misses trigger actual winter loss and its result screen")
        click(180, 418)
        page.wait_for_function("window.snowSnapshot.mode === 'title'")
        click(180, 377)
        page.wait_for_function("window.snowSnapshot.mode === 'preview'")
        for x, key, target, filename in [
            (140, "weather", 0.83, "warning"),
            (227, "weather", 1, "winter"),
            (314, "victory", True, "victory"),
        ]:
            click(x, 560)
            page.wait_for_function("([key, value]) => window.snowSnapshot[key] === value", arg=[key, target])
            page.wait_for_timeout(500)
            page.screenshot(path=str(output / f"browser-{filename}.png"))
        record("warning, cut-paper snow and flower-victory previews render")
        browser.close()
    assert not errors, errors
    report = {"passed": results, "browser_errors": errors, "note": "Headless Chromium uses software WebGL. This is not physical-device performance evidence."}
    (output / "browser-results.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8000/test/?test=1")
    parser.add_argument("--chromium", default="/usr/bin/chromium")
    args = parser.parse_args()
    run(args.url, args.chromium)
