# Mass Transcriptor (Phoenix + Turso)

Phoenix LiveView rewrite of [mass-transcriptor](../mass-transcriptor) with Turso/libSQL, Oban, and AssemblyAI.

## Stack

- Elixir / Phoenix LiveView
- Turso via `ecto_libsql` (local `dev.db` in development)
- Oban (`Oban.Engines.Lite`) for async transcription jobs
- Layout preserved from the React app (`styles.css` copied verbatim)

## Setup

```bash
cd mass-transcriptor-phoenix
mix setup
mix phx.server
```

Visit http://localhost:4000 — redirects to `/signin`.

## Environment

Copy `.env.example` and export variables for production (Turso URL/token, AssemblyAI key, `SECRET_KEY_BASE`).

## Tests

```bash
mix test
```

## Status

- [x] Auth + multi-tenant LiveView shells
- [x] Uploads + job creation + storage
- [x] AssemblyAI worker (Oban + Req)
- [x] Jobs list UI (grouping, status badges, polling)
- [ ] Job detail / batch detail UI
- [ ] Settings + full i18n

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
