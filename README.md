# Ruby Embassy

The conference companion app for **Rocky Mountain Ruby 2026** (Mon-Tue, Sep 28-29, eTown
Hall, Boulder CO): schedule, RSVPs, lightning talks, hack day, and the Ruby Embassy passport
application flow. It started as the app for Blue Ridge Ruby and was rebranded for RMR.

## Stack

- Ruby 3.4.4 (see `.ruby-version` / `.tool-versions`), Rails 8.1.2
- Postgres, with Solid Cache / Solid Queue / Solid Cable (no Redis)
- Hotwire (Turbo + Stimulus), importmap, no Node build step
- Propshaft for assets, Thruster in front of Puma
- Prawn for the Ruby Embassy passport PDF

## Third-party services (production)

| Service | Used for |
|---|---|
| [Railway](https://railway.com) | Hosting, Postgres, deploys |
| [Postmark](https://postmarkapp.com) | Outbound email (login links) |
| [Tito](https://ti.to) | Attendee ticketing and login lookup |

None of these are needed for local development. See Environment variables below for the
credentials each one requires.

## Development setup

```bash
bin/setup                # bundle install, db:prepare, clear log/tmp, then execs bin/dev
bin/setup --skip-server   # same, but stop before starting the server
bin/setup --reset         # also runs db:reset
bin/rails db:seed         # admin users, schedule, embassy question bank, idempotent
```

Postgres must already be running locally. Solid Queue runs in-process automatically in
development (`config/puma.rb:38` enables the Puma plugin whenever `Rails.env.development?`),
so background jobs, including login emails, work with no extra process to start.

### Signing in locally

Auth is a magic link, no password. Seeded admins are defined in `db/seeds.rb`. A plain
attendee is just:

```ruby
User.create!(email: "attendee@example.test", first_name: "Testy", last_name: "Attendee")
```

(`role` defaults to `attendee`, see `app/models/user.rb`.)

To sign in without going through email, mint a login URL directly in `bin/rails console`:

```ruby
user = User.find_by(email: "attendee@example.test")
token = user.generate_token_for(:login)
Rails.application.routes.url_helpers.callback_session_url(
  token: token, host: "localhost", port: 3000, protocol: "http"
)
```

Open that URL and submit the form on it. `SessionsController#callback` only establishes the
session on POST; a bare GET just renders the confirmation page.

## Tests

```bash
bin/rails test
bin/ci     # setup, rubocop, bundler-audit, importmap audit, brakeman, tests, seed replant
```

## Environment variables

Copy `.env.example` to `.env` and fill in what you need (`dotenv-rails` loads it
automatically in development and test, nothing to source by hand).

| Variable | Dev | Prod |
|---|---|---|
| `SECRET_KEY_BASE` | not needed | **Required** |
| `PRIMARY_DATABASE_URL` | not needed | **Required** (not needed if using the Railway template, see below) |
| `CACHE_DATABASE_URL` | not needed | **Required** (not needed if using the Railway template, see below) |
| `QUEUE_DATABASE_URL` | not needed | **Required** (not needed if using the Railway template, see below) |
| `CABLE_DATABASE_URL` | not needed | **Required** (not needed if using the Railway template, see below) |
| `SOLID_QUEUE_IN_PUMA` | auto-on | **Required** |
| `APP_HOST` | not needed | **Required** |
| `POSTMARK_API_TOKEN` | not needed | **Required** |
| `MAIL_PROVIDER` | not needed | optional (`postmark` default, or `brevo`) |
| `BREVO_API_KEY` | not needed | required only if `MAIL_PROVIDER=brevo` |
| `MAIL_FROM_ADDRESS` | not needed | optional, defaults to `noreply@rockymtnruby.dev` |
| `MISSION_CONTROL_USER` / `MISSION_CONTROL_PASSWORD` | optional | **Required** |
| `TITO_API_TOKEN` / `TITO_ACCOUNT_SLUG` / `TITO_EVENT_SLUG` | optional | **Required** |
| `RAILS_LOG_LEVEL`, `WEB_CONCURRENCY` | optional | optional |

### Switching email providers

`MAIL_PROVIDER` selects Postmark (`postmark`, the default when unset) or Brevo (`brevo`) —
either can be primary or backup, there's nothing structurally special about either one. Set
`MAIL_PROVIDER` and the matching provider's API key/token on Railway and redeploy; no code
change needed either direction.

The sender address (`MAIL_FROM_ADDRESS`, defaults to the one hardcoded in the app) is
independent of which provider is active. Whichever address you use must be verified with
whichever provider is currently selected — an unverified sender gets rejected by that
provider's API.

## Production / Railway deploy

This app already runs on Railway upstream. `bin/docker-entrypoint` runs `bin/rails db:prepare`
on every boot and bridges Railway's `$PORT` to Thruster's `$HTTP_PORT`. The `Dockerfile` is
auto-detected, no `railway.toml` or Nixpacks config needed.

The [Rails 8 Railway template](https://railway.com/deploy/railwayrails8starter) provisions four
separate Postgres services, one each for primary, cache, queue, and cable, and wires the four
`*_DATABASE_URL` variables to them automatically via Railway variable references. If you deploy
from that template, those four variables are already set for you and don't need any manual
configuration. If you provision your own single Postgres instead, point all four at it: each
connection has its own `migrations_paths`, so they coexist fine in one database.

1. Create a Railway project (from the template above, or your own).
2. Set the remaining required variables above that the template doesn't already provide.
3. Deploy.
4. Verify, in order, each step gating the next:
   1. Deploy succeeds; logs show `db:prepare` completing for all four databases.
   2. The `/up` healthcheck passes.
   3. Boot logs show SolidQueue starting its worker/supervisor.
   4. `/admin/jobs` prompts for HTTP basic auth rather than opening.
   5. A magic-link login works end to end, with the email actually arriving. This single test
      proves `SECRET_KEY_BASE`, `SOLID_QUEUE_IN_PUMA`, `APP_HOST`, and the Postmark token all
      at once. It's the test that actually matters.

Notes:
- Collaborators require a Railway Pro plan. Trial and Hobby plans cannot invite team
  members to a project. That's separate from adding admins to this app, which is just a row
  in `db/seeds.rb`.
- Postmark's free tier is 100 emails/month, which won't cover a full attendee list each needing
  a login link. Budget for that, or switch providers (a small change to
  `config/environments/production.rb`). Whichever provider you use, the sending domain needs
  SPF/DKIM verified or every send is rejected.

## Architecture notes

- Four logical databases (primary, cache, queue, cable) can share one Postgres instance, see
  above.
- `db/seeds/schedule.rb` can be run standalone to re-sync the schedule without re-running the
  admin-user seeds: `bin/rails runner db/seeds/schedule.rb`. Schedule content lives in
  `config/schedule.yml`.
- Never change an `external_id` in `db/seeds/embassy_questions.rb`, submitted applications
  reference them.
- `obsolete_slugs` in `db/seeds/schedule.rb` exists to clean up schedule items from
  pre-rebrand databases; leave it alone.
