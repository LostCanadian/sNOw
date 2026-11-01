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
        context = browser.new_context(viewport={"width": 360, "height": 640}, has_touch=True, device_scale_factor=1)
        page = context.new_page()
        page.on("dialog", lambda dialog: dialog.accept())
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
        # Create a named local campaign through the actual three-slot UI.
        page.wait_for_function("window.snowSnapshot?.mode === 'slots'")
        click(180, 242)
        page.wait_for_function("window.snowSnapshot?.mode === 'name'")
        click(180, 282)
        page.keyboard.press("Control+A")
        page.keyboard.type("Browser garden", delay=20)
        click(180, 342)
        page.wait_for_function("window.snowSnapshot?.mode === 'play'")
        assert page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1')).slots[0].name") == "Browser garden"
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
        page.wait_for_function("window.snowSnapshot.air > 0")
        # Position beneath a real, newly opened branch gap rather than the old sky band.
        gap_x = snap()["gaps"][0][0]
        expected_facing = 1 if gap_x > snap()["x"] else -1
        target_x = max(29, min(331, gap_x - expected_facing * 11.7))
        if abs(snap()["x"] - target_x) > 5:
            direction_key = "d" if snap()["x"] < target_x else "a"
            page.keyboard.down(direction_key)
            page.wait_for_function("target => Math.abs(window.snowSnapshot.x - target) < 6", arg=target_x)
            page.keyboard.up(direction_key)
        page.wait_for_function("Math.abs(window.snowSnapshot.aim) < 0.01")
        page.keyboard.down("Space")
        page.wait_for_function("window.snowSnapshot.rescued > 0", timeout=20000)
        page.screenshot(path=str(output / "browser-gameplay.png"))
        page.keyboard.up("Space")
        state = snap()
        assert state["attached"] + state["air"] + state["missed"] - state["regrown"] == state["slots"]
        record("keyboard movement and actual gust-to-empty-branch reattachment with conserved leaves")

        page.keyboard.press("Escape")
        page.wait_for_function("window.snowSnapshot.mode === 'paused'")
        frozen = snap()["time"]
        page.wait_for_timeout(500)
        assert snap()["time"] == frozen
        page.keyboard.press("Escape")
        page.wait_for_function("window.snowSnapshot.mode === 'play'")
        page.evaluate("window.dispatchEvent(new Event('blur'))")
        page.wait_for_function("window.snowSnapshot.mode === 'paused'")
        page.evaluate("window.dispatchEvent(new Event('focus'))")
        page.wait_for_timeout(300)
        assert snap()["mode"] == "paused", "returning to the page must not auto-resume"
        for width, height in [(360, 640), (390, 844), (360, 840), (768, 1024), (1280, 720)]:
            page.set_viewport_size({"width": width, "height": height})
            page.wait_for_function("""() => {
                const r = document.querySelector('canvas').getBoundingClientRect();
                return r.y >= -0.5 && r.y + r.height <= innerHeight + 1 &&
                       r.x >= -0.5 && r.x + r.width <= innerWidth + 1 &&
                       Math.abs(r.width / r.height - 9 / 16) < 0.002;
            }""")
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
        page.wait_for_function("window.snowSnapshot.mode === 'lost'", timeout=120000)
        page.wait_for_function("window.snowSnapshot.result_visible", timeout=20000)
        page.screenshot(path=str(output / "browser-winter-loss.png"))
        record("misses trigger actual winter loss and its result screen")
        ended_score = snap()["score"]
        click(180, 318)
        page.wait_for_function("window.snowSnapshot.mode === 'initials'")
        click(180, 258)
        page.keyboard.press("Control+A")
        page.keyboard.type("xyz", delay=20)
        click(116, 445)
        page.wait_for_function("window.snowSnapshot.mode === 'scores' && window.snowSnapshot.score_rows[1] === 1")
        score_document = page.evaluate("JSON.parse(localStorage.getItem('snow.highscores.v1'))")
        assert score_document["tables"][1][0]["initials"] == "XYZ"
        assert score_document["tables"][1][0]["score"] == ended_score
        click(180, 554)
        page.wait_for_function("window.snowSnapshot.mode === 'lost'")
        click(180, 368)
        page.wait_for_function("window.snowSnapshot.mode === 'play'")
        assert snap()["week"] == 1 and snap()["tiers"] == [0, 0, 0]
        assert snap()["week_missed"] == 0 and snap()["attached"] + snap()["air"] == 288
        page.keyboard.press("Escape")
        page.wait_for_function("window.snowSnapshot.mode === 'paused'")
        click(180, 386)
        page.wait_for_timeout(200)
        click(180, 382)
        page.wait_for_function("window.snowSnapshot.mode === 'title'")
        record("loss retries the same week; confirmed exit retains the saved campaign")
        page.reload(wait_until="networkidle")
        page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
        click(113, 427)
        page.wait_for_function("window.snowSnapshot.mode === 'scores' && window.snowSnapshot.score_rows[1] === 1")
        page.screenshot(path=str(output / "browser-high-scores.png"))
        page.locator("canvas").screenshot(path="docs/images/prototype-high-scores.png")
        record("initials entry saves the actual terminal score; local top ten survives reload")
        click(180, 554)
        page.wait_for_function("window.snowSnapshot.mode === 'title'")
        # Isolated, validated workshop fixture: this tests UI/persistence, not a played win.
        fixture = json.loads(Path("test-results/visual-fixture.json").read_text())
        document = page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1'))")
        document["slots"][1] = fixture["slots"][2]
        page.evaluate("data => localStorage.setItem('snow.campaigns.v1', JSON.stringify(data))", document)
        page.reload(wait_until="networkidle")
        page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
        click(180,323)
        page.wait_for_function("window.snowSnapshot.mode === 'slots'")
        click(180,322)
        page.wait_for_function("window.snowSnapshot.mode === 'workshop'")
        assert snap()["points"] == 1
        click(180,222)  # Inspect Fan rank 1.
        page.wait_for_function("window.snowSnapshot.selected_upgrade[0] === 1")
        click(96,536)   # Explicit Buy action, separate from inspection.
        page.wait_for_function("window.snowSnapshot.tiers[1] === 1 && window.snowSnapshot.points === 0")
        click(180,362)  # Locked rank 6 still has a readable description.
        page.wait_for_function("window.snowSnapshot.selected_upgrade[1] === 6")
        assert snap()["tiers"] == [0,1,0]
        page.screenshot(path=str(output / "browser-workshop.png"))
        click(296,135)  # Refund the kit.
        page.wait_for_function("window.snowSnapshot.points === 1 && window.snowSnapshot.tiers[1] === 0")
        click(180,222)
        page.wait_for_function("window.snowSnapshot.selected_upgrade[0] === 1")
        click(96,536)
        page.wait_for_function("window.snowSnapshot.tiers[1] === 1")
        record("workshop fixture: inspect locked nodes, buy explicitly and refund without overlapping controls")
        page.reload(wait_until="networkidle")
        page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
        click(180,323)
        page.wait_for_function("window.snowSnapshot.mode === 'slots'")
        click(180,322)
        page.wait_for_function("window.snowSnapshot.mode === 'workshop'")
        assert snap()["tiers"] == [0,1,0] and snap()["points"] == 0
        click(261,536)
        page.wait_for_function("window.snowSnapshot.mode === 'play' && window.snowSnapshot.week === 2")
        assert snap()["week_missed"] == 0 and snap()["tiers"] == [0,1,0]
        page.reload(wait_until="networkidle")
        page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
        click(180,323)
        page.wait_for_function("window.snowSnapshot.mode === 'slots'")
        click(180,322)
        page.wait_for_function("window.snowSnapshot.mode === 'paused'")
        assert snap()["week"] == 2 and snap()["tiers"] == [0,1,0] and snap()["week_missed"] == 0
        record("workshop fixture: saved upgrades, next-week checkpoint and explicit resume survive reload")
        click(180,387)
        page.wait_for_timeout(300)
        click(180,383)
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
    report = {"passed": results, "browser_errors": errors, "note": "Headless Chromium uses software WebGL. The early loss/score are played; workshop checks use an explicitly validated UI fixture. This is not physical-device performance evidence."}
    (output / "browser-results.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8000/test/?test=1")
    parser.add_argument("--chromium", default="/usr/bin/chromium")
    args = parser.parse_args()
    run(args.url, args.chromium)
