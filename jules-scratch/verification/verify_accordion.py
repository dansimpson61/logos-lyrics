from playwright.sync_api import sync_playwright, Page, expect

def run_verification(page: Page):
    """
    This script verifies the new accordion panel functionality.
    """
    # 1. Navigate to the app
    page.goto("http://localhost:9292")

    # 2. Click the search icon to expand the panel
    search_icon = page.locator(".search-icon")
    search_icon.click()

    # 3. Verify that the search input receives focus
    search_input = page.get_by_placeholder("Search...")
    expect(search_input).to_be_focused()
    page.screenshot(path="jules-scratch/verification/01_panel_expanded.png")

    # 4. Perform a search
    search_input.fill("Queen")
    search_input.press("Enter")

    # 5. Verify that the results are displayed within the panel
    expect(page.get_by_role("heading", name="Queen")).to_be_visible(timeout=10000)
    page.screenshot(path="jules-scratch/verification/02_panel_results.png")

    # 6. Click a result
    track_to_click = page.get_by_text("Bohemian Rhapsody", exact=False).first
    track_to_click.click()

    # 7. Verify that the panel collapses
    search_panel = page.locator(".search-panel")
    expect(search_panel).not_to_have_class("is-expanded")

    # 8. Verify that the lyrics are displayed
    lyrics_container = page.locator(".lyrics-container")
    expect(lyrics_container).to_contain_text("Is this the real life?", timeout=10000)
    page.screenshot(path="jules-scratch/verification/03_lyrics_displayed.png")

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        run_verification(page)
        browser.close()

if __name__ == "__main__":
    main()
