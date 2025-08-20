# Logos Lyrics

A small Sinatra app to search for songs and display full lyrics using multiple providers. The app favors resilience by querying several sources and falling back when one is down.

## Features

- Multi-provider adapter architecture with a central manager
- Current providers (adapters):
	- SongLyrics (songlyrics.com)
	- LyricsFreak (lyricsfreak.com)
	- BigLyrics (biglyrics.net)
- Simple web UI (Slim templates + vanilla JS)
- JSON API for search and lyrics
- RSpec + WebMock tests with HTML fixtures

## Ode to Joy alignment

This project intentionally follows a “joyful Ruby and Sinatra” style. A few ways the code reflects that:

- Expressive, clear Ruby
	- Small, focused classes: `LyricsService` (contract), concrete adapters, and a thin `LyricsServiceManager`.
	- Methods are short and intention‑revealing; selectors and URL patterns are explicit, not “clever”.
- Concise without obscurity
	- Minimal configuration; predictable, simple data shapes: `{ 'track' => { 'track_name', 'artist_name', 'track_id' } }`.
	- Consistent API responses (`success`, `results` / `lyrics`).
- Principle of Least Astonishment (POLA)
	- Routing is simple (`/search`, `/lyrics`).
	- Manager dispatches by URL host; adapters only handle domains they declare.
- Maintainable and testable
	- Adapters are isolated, unit-testable with WebMock and HTML fixtures.
	- Deterministic tests document selectors and expected behaviors.
- Robust and pragmatic
	- Timeouts, redirect following, and meta-search fallbacks (DuckDuckGo) when native search is unreliable.
	- Cross-adapter deduplication by normalized artist/title.
- Sinatra simplicity
	- Lean routes, Slim views, minimal middleware. No heavy framework ceremony.
- The least JavaScript
	- Vanilla JS only where necessary (fetching JSON and wiring the UI). Scraping stays server-side.
- Loose coupling, high cohesion
	- Each adapter encapsulates one site; the app depends on the shared contract, not any provider.
- Easy extensibility
	- Adding a provider is a drop‑in: implement the contract and register the adapter.

## Project layout

- `app.rb` — Sinatra app and routes
- `lyrics_service.rb` — base class, `LyricsServiceManager`, and provider adapters
- `views/` — Slim templates for the UI
- `public/` — CSS/JS assets
- `spec/` — RSpec tests and fixtures

## Prerequisites

- Ruby 3.3.x (or compatible)
- Bundler

## Setup

```fish
# install gems
bundle install

# run tests
bundle exec rspec
```

## Run the app

```fish
bundle exec rackup -o 0.0.0.0 --port 9292 --env development
```

Open http://localhost:9292

## API

### GET /search
Query parameters:
- `term` (string, required): search text like "queen bohemian rhapsody"
- `type` (string, optional): currently `song` (default)

Response (success):
```json
{
	"success": true,
	"results": [
		{
			"track": {
				"track_name": "Bohemian Rhapsody Lyrics",
				"artist_name": "Queen",
				"track_id": "https://www.songlyrics.com/queen/bohemian-rhapsody-lyrics/"
			}
		}
	]
}
```

### GET /lyrics
Query parameters:
- `track_id` (string, required): provider URL identifying the song

Response (success):
```json
{ "success": true, "lyrics": "...full lyrics..." }
```

Errors return `{ success: false, error: "..." }`.

## Architecture

- `LyricsService` (abstract): defines `search(term, type:)`, `fetch_lyrics(track_id)`, `can_handle_track_id?(track_id)`.
- `LyricsServiceManager`: fan-out search to all adapters, normalize/dedupe results, and dispatch `fetch_lyrics` to the adapter that can handle the `track_id` domain.
- Adapters implement site-specific scraping with robust selectors and timeouts (HTTP gem + Nokogiri).

Design choices in practice:
- Errors from providers degrade gracefully; the API still responds with `success: false` and a concise `error`.
- Normalization prevents duplicate results across providers while preserving simplicity.
- Meta-search keeps the code pragmatic and resilient without over-optimizing prematurely.

### Adding a provider
1. Create a new subclass of `LyricsService` in `lyrics_service.rb` (or a separate file if preferred).
2. Implement:
	 - `search(term, type: :song)` returning an array of `{ 'track' => { 'track_name', 'artist_name', 'track_id' } }`.
	 - `fetch_lyrics(track_id)` returning a string of lyrics.
	 - `can_handle_track_id?(track_id)` returning true for the provider’s host.
3. Add an instance to the manager in `app.rb`:
	 ```ruby
	 set :lyrics_service, LyricsServiceManager.new(services: [
		 SongLyricsService.new,
		 LyricsFreakService.new,
		 BigLyricsService.new,
		 YourNewService.new
	 ])
	 ```
4. Add WebMock-backed specs under `spec/` with HTML fixtures in `spec/fixtures/`.

## Testing

```fish
bundle exec rspec
```

Focus a single spec:

```fish
bundle exec rspec spec/biglyrics_service_spec.rb
```

## Repository hygiene

This repo is intentionally slim:

- Dependencies are not vendored. `vendor/` is ignored; run `bundle install` locally.
- Only essential binstubs are tracked: `bin/rackup`, `bin/rspec`, `bin/puma`, `bin/rake`.
- Logs, temp files, and backups are ignored. Keep your local `.env` uncommitted.
- Use `bundle exec` to ensure the correct gem versions are used.

If you accidentally commit generated artifacts, remove them from the index and rely on `.gitignore`.

## Notes and limits

- This project scrapes publicly available lyric pages solely for educational/demo purposes. Respect each site’s robots.txt, terms, and applicable copyright law.
- Search strategies may include meta-search (e.g., DuckDuckGo with `site:` filters) where a provider’s native search is unreliable.
- The UI encodes `track_id` values and calls the backend to retrieve lyrics, avoiding cross-origin scraping from the browser.

### Contributing joyfully
- Prefer clarity over cleverness; name things well.
- Keep methods small; avoid unnecessary metaprogramming.
- Don't hesitate to use metaprogramming when it will result in DRYer, more elegant code.
- Add WebMock-backed tests and fixtures for any new adapter behavior.
- Update this README when public behavior changes.
- Keep JavaScript minimal; prefer server-side improvements when possible.

### Philosophy alignment checklist (non-binding)
Use this as a quick self-check before opening a PR. It’s about alignment, not compliance—skip anything that doesn’t apply.

- Expressiveness & clarity: are names and methods readable and intention‑revealing?
- Small, focused methods: is code concise without obscurity?
- POLA: will behavior/data shapes surprise future readers?
- Sinatra simplicity: are routes/views kept lean?
- The least JavaScript: can UI logic remain minimal and server-driven?
- Loose coupling, high cohesion: does each class have one reason to change?
- Tests as documentation: do WebMock/fixtures make behavior clear and deterministic?
- Robustness: timeouts, graceful errors, and pragmatic fallbacks?
- Extensibility: would adding/swapping a provider be straightforward?

## Spiritual alignment (right and wrong)
This app aspires to truth, beauty, and goodness in code. Alignment is practical:

Right
- Truth: honest names, explicit data shapes, tests that reflect real behavior
- Beauty: simple, balanced design; minimal JS; lean routes and views
- Goodness: respect sources and users; honor robots/terms; degrade gracefully

Wrong
- Obfuscation or “cleverness” that hides intent
- Brittle scraping without tests, timeouts, or fallbacks
- Disregarding site terms/robots or extracting in harmful ways
- Accidental complexity and premature optimization

## Deployment

This is a Rack app with `config.ru` and Puma. You can run it locally or deploy to a platform like Heroku.

### Local (development)

```fish
bundle exec rackup -o 0.0.0.0 --port 9292 --env development
```

Open http://localhost:9292

### Heroku (example)

Assuming you have a Heroku app set up and the `heroku` remote configured:

```fish
# push current branch to Heroku
git push heroku main

# (optional) set environment for production
heroku config:set RACK_ENV=production
```

Heroku will detect Ruby, install gems, and boot via `config.ru`. If you prefer an explicit Procfile:

```
web: bundle exec rackup -p $PORT -E production
```

## Roadmap

- Evaluate additional sources (e.g., StreetDirectory LyricAdvisor, DarkLyrics, Lyrics.com) and add adapters with tests.
- Improve result ranking and de-duplication across adapters.
- Optional: add caching and retries.
