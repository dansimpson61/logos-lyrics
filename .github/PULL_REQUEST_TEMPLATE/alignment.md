## Summary
- What does this change do?

## Motivation
- Why is this change worth making now?

## Alignment checklist (philosophy-first, non-blocking)
This is a gentle prompt to reflect on the Ode to Joy. Check what feels true; leave blank if not applicable.

- [ ] Expressiveness & clarity: names and methods read like prose
- [ ] Small, focused methods; no unnecessary cleverness
- [ ] POLA: behavior is unsurprising; data shapes are consistent
- [ ] Sinatra simplicity: lean routes, minimal middleware
- [ ] The least JavaScript: keep scraping/server logic on the backend
- [ ] Loose coupling, high cohesion: each class has one reason to change
- [ ] Tests document intent (WebMock + fixtures for scraping)
- [ ] Robustness: timeouts, graceful failures, simple fallbacks
- [ ] Extensibility: easy to add/replace providers without ripple effects

## Spiritual alignment (optional)
Right
- Truthful names and explicit data shapes; tests reflect real behavior
- Simple, balanced design; minimal JS; lean routes and views
- Respect sources and users (robots/terms); degrade gracefully

Wrong
- Obfuscation/cleverness that hides intent
- Brittle scraping without tests/timeouts/fallbacks
- Ignoring site terms/robots; accidental complexity and premature optimization
- ugly, machine-centered code

## Screenshots / Demos

## Risks & mitigations

## Follow-ups
- e.g., docs to update, next adapter to add, debt to tidy
