# IMDb repository fixtures

Captured public GraphQL responses from 2 October 2026, retained from the initial
backend investigation. `repository_test.dart` uses these six responses to check
movie/series mapping and episode/review pagination without network access.
They describe historical payloads, not a current provider availability check.
Current request documents live in `lib/imdb/queries/`.
