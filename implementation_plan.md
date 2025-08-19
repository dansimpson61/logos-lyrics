
# Implementation Plan

This document outlines the plan for implementing the recommendations from the project assessment.

## 1. Address the JavaScript Situation: Refactor to Vanilla JavaScript

*   **Goal:** Remove the jQuery dependency and replace it with vanilla JavaScript to align with the "least javascript" principle.
*   **File to Modify:** `public/logos.js`
*   **Plan:**
    1.  **Remove jQuery:** Delete the jQuery library from the project.
    2.  **Replace DOMContentLoaded:** Replace `$(document).ready()` with `document.addEventListener('DOMContentLoaded', () => { ... });`.
    3.  **Replace Selectors:** Replace `$('#id')` with `document.getElementById('id')` or `document.querySelector('#id')`.
    4.  **Replace Event Listeners:** Replace `.on('event', handler)` with `.addEventListener('event', handler)`.
    5.  **Replace AJAX:** Replace `$.getJSON()` with `fetch()`.
    6.  **Replace DOM Manipulation:** Replace `.html()`, `.empty()`, and `.append()` with `innerHTML`, `innerHTML = ''`, and `appendChild()` respectively.
    7.  **Remove Automatic Search:** Remove the `this.performSearch('test');` line.

## 2. Implement the Core Functionality

*   **Goal:** Implement the service manager, fix method signatures, complete the `ChartLyricsService`, and replace hardcoded search results.
*   **Files to Modify:** `lyrics_service.rb`, `app.rb`
*   **Plan:**

    *   **A. Implement the Service Manager (`lyrics_service.rb`)**
        1.  Create a new class `LyricsServiceManager`.
        2.  In the `LyricsServiceManager` constructor, initialize instances of all available lyric services (`SongLyricsService`, `ChartLyricsService`, etc.) and store them in an array.
        3.  Create a `search` method in `LyricsServiceManager` that takes a search term.
        4.  Inside the `search` method, iterate over the array of services and call the `search` method on each one.
        5.  Collect the results from all services, merge them, and remove duplicates.
        6.  Return the merged and deduplicated results.

    *   **B. Fix Method Signatures (`lyrics_service.rb`)**
        1.  In the `LyricsService` base class, define the `search` method with a signature that can accommodate all services. A good signature would be `search(term, type: :song)`. The `type` parameter can be used to specify whether the search is for a song or an artist.
        2.  Update the `search` method in all subclasses (`SongLyricsService`, `ChartLyricsService`) to match the new signature.

    *   **C. Complete the `ChartLyricsService` (`lyrics_service.rb`)**
        1.  Implement the checksum calculation logic for the `fetch_lyrics` method. This will likely involve researching the ChartLyrics API documentation.
        2.  Remove the hardcoded search results from the `search` method and replace them with a call to the ChartLyrics API.

    *   **D. Replace Hardcoded Search Results (`app.rb`)**
        1.  In `app.rb`, remove the hardcoded search results from the `/search` endpoint.
        2.  Instantiate the `LyricsServiceManager`.
        3.  In the `/search` endpoint, call the `search` method on the `LyricsServiceManager` instance and return the results.

## 3. Improve Code Quality

*   **Goal:** Use environment variables for secrets, add more tests, and remove the automatic "test" search on page load.
*   **Files to Modify:** `lyrics_service.rb`, `spec/lyrics_service_spec.rb`, `public/logos.js`, `Gemfile`, `.gitignore`
*   **Plan:**

    *   **A. Use Environment Variables**
        1.  Add the `dotenv` gem to the `Gemfile`.
        2.  Create a `.env` file to store API keys and other secrets.
        3.  Add `.env` to the `.gitignore` file.
        4.  In `lyrics_service.rb`, use `ENV['CHARTLYRICS_API_KEY']` to access the API key.

    *   **B. Add More Tests (`spec/lyrics_service_spec.rb`)**
        1.  Write tests for the `LyricsServiceManager`.
        2.  Write tests for the `ChartLyricsService` (once it's complete).
        3.  Use a library like `webmock` to stub out the HTTP requests to the lyric services.

    *   **C. Remove Automatic Search (`public/logos.js`)**
        1.  As mentioned in the JavaScript refactoring plan, remove the `this.performSearch('test');` line.
