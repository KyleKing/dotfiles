---
name: observability-clis
description: Query PostHog error tracking and Sentry issues from the command line. Use when asked what errors are happening, which errors are being missed or untriaged, for production error rates or impact by user, or whenever posthog-cli or sentry-cli is mentioned.
---

# Observability CLIs

Both tools have quirks that waste turns if rediscovered. Org and project slugs are
project-specific — check that project's `CLAUDE.local.md`.

## PostHog

The binary is `posthog-cli`, installed via mise. The agent-first surface is
`posthog-cli api`:

```sh
posthog-cli api search <regex>              # find tools
posthog-cli api info --json <tool>          # get a schema
posthog-cli api call --json <tool> '<json>' # run one
```

For "what errors are happening" or "what is being missed", use
`query-error-tracking-issues-list`. It defaults to active issues, the last 7 days,
sorted by occurrences, with test accounts filtered out.

For impact rather than volume:

```sh
posthog-cli api call --json query-error-tracking-issues-list \
  '{"dateRange":{"date_from":"-30d"},"orderBy":"users"}'
```

`assignee: null` across the board means nobody is triaging.

Project is likely 420833 on `us.posthog.com`.

## Sentry

`sentry-cli` uses a personal read token in `~/.sentryclirc`.

The `--org` flag goes **after** the subcommand, not before:

```sh
sentry-cli projects --org <org> list
```

There is no issues-list subcommand. Query issues through the REST API with the same
token:

```sh
curl -H "Authorization: Bearer <token>" \
  "https://sentry.io/api/0/projects/<org>/<project>/issues/?statsPeriod=24h&query=is:unresolved&sort=freq&limit=15"
```

Useful `query` filters: `is:unresolved`, an endpoint path, `N+1`.

Parse responses with `json.loads(..., strict=False)`. Bodies contain raw control
characters inside SQL strings and strict parsing fails on them.
