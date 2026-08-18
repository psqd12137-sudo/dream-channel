#!/usr/bin/env python3
"""验证：测 Boss 菜单可选新 Boss 进入决战。"""
import sys

from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8787/"


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        page.goto(URL, wait_until="domcontentloaded", timeout=15000)
        page.wait_for_timeout(1000)

        # 打开测 Boss 菜单
        page.evaluate("window.CabinDebug.offerBossTestMenu()")
        page.wait_for_timeout(400)

        # 检查对手选择行
        pick_btns = page.evaluate("""() => {
            const row = document.querySelector('.event-boss-pick');
            if (!row) return null;
            return Array.from(row.querySelectorAll('button')).map(b => b.textContent);
        }""")
        print("对手选择行:", pick_btns)
        if not pick_btns or not any("★" in t for t in pick_btns):
            print("FAIL: 对手选择行未渲染新 Boss")
            browser.close()
            sys.exit(1)

        # 选「星位司仪」→ 点第一个牌组按钮
        clicked = page.evaluate("""() => {
            const row = document.querySelector('.event-boss-pick');
            const btns = Array.from(row.querySelectorAll('button'));
            const target = btns.find(b => b.textContent.includes('星位司仪'));
            if (!target) return false;
            target.click();
            return true;
        }""")
        print("选中星位司仪:", clicked)
        page.wait_for_timeout(300)

        # 检查选中高亮 + 确认 bossTestPick
        sel = page.evaluate("""() => {
            const chosen = document.querySelector('.boss-pick-btn.chosen');
            return { chosen: chosen ? chosen.textContent : null, pick: bossTestPick };
        }""")
        print("选中状态:", sel)

        # 点第一个牌组进入决战
        page.evaluate("""() => {
            const box = document.getElementById('event-choices');
            const deckBtns = Array.from(box.querySelectorAll('button')).filter(b => !b.closest('.event-boss-pick'));
            const first = deckBtns[0];
            if (first) first.click();
        }""")
        page.wait_for_timeout(900)

        # 确认 chosenBoss
        boss = page.evaluate("state.chosenBoss")
        print("进入决战 Boss:", boss)
        if boss != "stars_align":
            print(f"FAIL: 期望 stars_align 得到 {boss}")
            browser.close()
            sys.exit(1)

        # 确认 Boss 界面标题
        title = page.evaluate("document.getElementById('boss-name')?.textContent")
        print("Boss 界面标题:", title)

        print("\nPASS: 测 Boss 菜单可选新 Boss 并进入决战")
        browser.close()


if __name__ == "__main__":
    main()
