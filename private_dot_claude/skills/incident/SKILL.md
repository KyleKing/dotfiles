---
name: incident
description: incident.io assistant for working with incidents. View incident details, post updates to incident channels, interact with the incident agent, and query structured incident data. Use whenever the user mentions an incident ID (e.g., "INC-123"), asks about an incident, or uses the /incident command. Trigger proactively when you see an incident reference.
allowed-tools:
  - Read
---

# incident.io

This skill helps you work with incident.io incidents using the incident.io
MCP tools.

## When to Use

Activate this skill when the user:

- Runs `/incident setup` — call the `setup` MCP tool to get started
- Mentions ANY incident ID in their message (e.g., "I'm working on INC-123",
  "looking at inc-456")
- Refers to "my incident", "the current incident", or similar
- Says they're working on an incident or got paged
- Asks to investigate or debug an incident
- Wants to share findings back to an incident
- Says "@incident" followed by any request

**Important**: Trigger this skill proactively whenever you see an incident
reference — don't wait for explicit requests.

## Quick Start (Decision Tree)

When this skill activates, follow this decision tree:

1. **User provides an incident ID** (e.g., "INC-123")
   → Use `incident_pin` tool, then use `ask_incident` to get a summary
   of the incident

2. **User says "my incident", "the incident", "pinned incident", or is
   looking for their current incident**
   → Use `incident_pin` tool (no args) to check currently pinned incident
   → If one is pinned, get its details — no need to search or list
   → If none, fall back to step 3

3. **No incident ID provided** (e.g., "I got paged")
   → Use `escalations_list` tool to list relevant incidents
   → Present brief options, let user choose, then pin

**After pinning**: Use `ask_incident` to get a summary of the incident,
or use the data tools to query specific details.

## Multi-select Interactions

When presenting the user with a list of options (e.g., choosing from multiple
escalations, selecting incidents to investigate, picking from suggested actions),
use the `AskUserQuestion` tool to power the interaction. This gives the user a
structured selection experience rather than requiring them to type their choice
as free text.
# incident.io Investigation Guide

You have access to incident.io's tools for investigating incidents.
Here's how to use them effectively.

## Requirements

Authentication is stored in the macOS Keychain. If you encounter auth errors,
prompt the user to authenticate in the incident.io macOS app.

## Available MCP Tools

### Core Tools

- `escalations_list` — Find incidents where you were paged
- `incident_pin` — Set, check, or clear which incident you're working on
- `identity_get` — Get your user identity (email, name, ID) for attribution
- `incident_message` — Post updates to an incident channel

### Data Tools

These tools query structured incident, alert, and escalation data:

- `incident_show` — Get full incident details. For investigation work, always
  use `include: ["investigation", "postmortem"]` to get AI investigation
  findings and the post-mortem — the default response only has basic metadata.
- `incident_list` — Search incidents with filters. Use `include: ["roles"]`
  or `include: ["custom_fields"]` for analytical queries.
- `incident_stats` — Aggregate counts and workload by severity, team, alert
  source, time period, etc. Start here for analytical questions.
- `incident_create` — Create a new incident with structured parameters.
- `incident_update` — Update incident fields (status, severity, roles, etc.).
- `alert_list`, `alert_show`, `alert_stats` — Query and analyse alerts.
  `alert_stats` includes workload from linked incidents.
- `escalation_list`, `escalation_show`, `escalation_stats` — Query pages.
- `follow_up_list`, `follow_up_create` — Manage post-incident follow-ups.
- `schedule_list`, `schedule_show` — View on-call schedules and rotations.
- `catalog_type_list`, `catalog_entry_list`, `catalog_entry_show` — Browse
  the service catalog.

Read `config://organisation` to discover severity IDs, custom field IDs,
role IDs, and other values needed for filtering.

For analytical work, read `playbook://analysis` — it describes strategies
for incident, alert, and escalation analysis using the stats tools.

### Agent Tools

These tools connect to incident.io's backend agents:

- `ask` — Ask the general AI agent a question (org queries, catalog, on-call,
  schedule management including overrides)
- `ask_incident` — Ask the incident AI agent about a specific incident (post
  updates, change status, create actions, draft communications)

Use `ask_incident` when you need to take actions only the incident agent can
perform. Use `incident_message` when sharing information you've already analyzed.

For structured data (counts, filtering, specific fields), prefer the data
tools above — they're faster and cheaper than the agent tools. Use agent
tools when you need AI reasoning, entity resolution, or multi-step actions.

### Session management for agent tools

Both agent tools (`ask`, `ask_incident`) support multi-turn conversations.
Each response is a JSON object containing `session_id`, `response`,
`outcome`, and optionally `image_urls`.

- **First call**: omit `session_id`. The response includes a new one.
- **Follow-up calls**: pass `session_id` from the previous response to
  continue the conversation with full context.
- **New topic**: omit `session_id` to start a fresh conversation, even for
  the same incident.

Always continue the same session when making related requests (e.g., asking a
question then accepting the resulting suggestion). Start a new session when
switching to an unrelated topic.

## Workflow

### Step 1: Find the incident

**If user mentions an incident ID**, skip to step 2.

**If user says "my incident"**, use `incident_pin` with no arguments to
check their currently pinned incident. If one is pinned, skip to step 3.

**If no incident ID**, use `escalations_list` to find relevant incidents:

1. Look at the output for the current user's email and `← YOU` markers
2. Present a brief, single-line summary of the top 3-5 incidents:
   ```
   1. INC-123 Database CPU is high (paged 2 min ago)
   2. INC-456 API Gateway timeouts (created 15 min ago)
   ```
3. Ask the user which incident they want to investigate

**Important:** Don't show full escalation details — just brief summaries. Make
a recommendation if one is clearly most relevant.

### Step 2: Pin the incident

Use `incident_pin` with the incident ID. This sets the incident as active
in the macOS app.

```
incident_pin(incident_id="INC-12345")  // Set active
incident_pin()                         // Check current
incident_pin(unset=true)               // Clear
```

### Step 3: Get incident details

Use `ask_incident` to get a summary of what's happening, or use
`incident_show` to get structured incident data.

### Step 4: Help the user

Analyze the incident data, answer questions, and help debug.

### Step 5: Share findings back

Use the `incident_message` tool with the two-part structure:

- `message`: Brief summary (1-2 sentences, no emojis/headers/bullets)
- `thread_message`: Optional — technical details, code snippets, full analysis
- `user`: Use the user's full name from `identity_get` (e.g., "Lawrence Jones"),
  or "incident.io" if unknown

**When to use threads:**

- Main message: Brief summary of what was found/fixed
- Thread: Code snippets, logs, detailed explanations, test results

**Skip threads for:** Simple status updates and quick confirmations.

## Message Formatting Guidelines

**Language and tone.** You are communicating on behalf of a human, so
your job is to faithfully represent what they did and found.

- **Preserve the user's level of certainty** — use the same hedging
  language they used. If the user says "I believe X might be causing
  this", keep that tentativeness: "likely", "appears to be", "looks
  like." Only state something definitively when the user has.
- **Use factual language** — describe what was observed and done:
  "found that X appears to be causing Y", "pushed a fix for Z",
  "traced the problem to W." Stick to claims the user actually made.
  Prefer "the issue" or "the cause" over "root cause", which implies
  a level of certainty you should leave to the user.
- **Match the user's framing exactly** — if they pushed a fix, say
  they pushed a fix. If they're still investigating, say that. Describe
  what was done rather than reinterpreting it with stronger or weaker
  language.
- **Only share what the user asked you to share** — if you've read
  investigation data but the user hasn't stated a finding, wait for
  them to tell you what to post. Represent their conclusions, not
  your own.

**Main message:**

- 1-2 sentences max, punchy and conversational
- Use first-person ("I've found...", "I've pushed a fix...")
- Use `inline code` for paths, function names, values
- Use **bold** sparingly for key outcomes (**fixed**, **deployed**)
- Hyperlink URLs: `[descriptive text](url)`
- NO emojis, headers, or bullet points
- If you have details, put them in thread and mention "see thread"

**Thread message:**

- Full technical details, code blocks, logs
- Use **bold text** for section titles (not markdown headers)
- Use sentence case for all text including section titles
- Use bullet lists and code blocks for organization

**Good example — confirmed fix:**

```
message: "Pushed a fix for the connection pool exhaustion — there was a
missing index on `users.email`. Query time `5s → 50ms` (PR#5678). See
thread for details."

thread_message: "**What happened**\n\nThe `users` table was doing full
table scans on every login..."
```

**Good example — still investigating:**

```
message: "Looked into the connection pool exhaustion — it looks like a
missing index on `users.email` might be the cause. Still confirming.
See thread for what I've found so far."
```

## Presenting Data to Users

When presenting incident data, investigation findings, or analytical results
to the user directly (not via `incident_message`):

- **Lead with the reference** — always include INC-123, severity, and status
  to orient the reader.
- **Preserve confidence levels** — when presenting AI investigation findings
  from `incident_show(include: ["investigation"])`, keep the hedging language
  (e.g. "appears to be", "likely caused by"). Don't overstate certainty.
- **Convert workload to hours** — workload data from stats tools is in
  minutes. Present as hours for readability: "42 hours of responder time
  (8 hours overnight)".
- **Highlight the significant** — for stats results, lead with the most
  impactful groups (highest count, most workload, biggest change over time)
  rather than listing everything.
- **Make linkages explicit** — when showing alert and incident data together,
  connect them: "Alert X from Datadog triggered INC-123, which consumed
  12 hours of responder time."

## The @incident Pattern

When the user says **"@incident [request]"**, this activates the incident.io tools.
Route to the appropriate agent based on the question type:

- **Incident actions** (status, severity, roles, updates, follow-ups) →
  `ask_incident`
- **Organisation queries** (on-call, catalog, schedules) → `ask`

### Expanding requests

The backend agent cannot see your session. It has no visibility of the
code you read, the fixes you made, or the PRs you pushed.

Before dispatching, consider whether the backend agent needs context
from your session to handle the request well. If the user says "send an
update" after you've spent 20 minutes debugging and pushing a fix, the
backend agent has no idea what the update should say — you need to
provide that context. But if the user says "change status to resolved",
that's already self-contained and doesn't need expansion.

**When context is needed, translate the user's request into a
self-contained question that includes the relevant details from your
session**, so the backend agent can act on it without needing any other
context.

**Bad — passing through raw text:**

```
User: @incident send an update

question: "send an update"
```

The backend agent doesn't know what the update should say.

**Good — expanding with session context:**

```
User: @incident send an update

question: "Send an update to say we found the trace image renderer was
spending ~2 minutes in a tight font glyph-loading loop, causing
excessive memory pressure on the worker-ai pod. We've pushed a fix in
commit ff35f9c that replaces the O(n^2) truncation loop with a
single-pass truncateToWidth approach."
```

This applies to both agent tools. A few more examples:

- `@incident send an update` → Summarize what you found and did in your
  session, pass that as the question to `ask_incident`
- `@incident who is on-call for platform?` → Route to `ask`
- `@incident change status to resolved` → Verify it's appropriate, then
  use `ask_incident`

## Handling Suggestions

**Requesting suggestions:** When the user asks to "suggest" something (e.g.,
"suggest an incident update", "suggest a summary"), use `ask_incident` to
request it. Don't generate suggestions locally — the backend agent has the
context and tools to create proper suggestions.

**Processing suggestions:** The `ask_incident` response JSON may include a
`suggestion` field. If present, always present it to the user for approval
before actioning.

**Step 1: Parse and present the suggestion**

The `suggestion` object has `id`, `suggestion_type`, and `content`. Parse the
content and format it as a visible box:

```
┌─ Suggestion ─────────────────────────────────────┐
│ Type: update                                     │
│ Changes: Status → Monitoring, Severity → SEV-2  │
├──────────────────────────────────────────────────┤
│ [accept] [decline] [update]                      │
└──────────────────────────────────────────────────┘
```

Content field mappings for the `update` type:

- `incident_status_name` → "Status → {value}"
- `severity_id` → "Severity → {value}"
- `name` → "Name → {value}"
- `message` → show the message text

Other suggestion types include `role`, `follow_up`, and `escalation` — format
them descriptively based on the content fields present.

**Step 2: Wait for user response**

- **accept** → accept the suggestion as-is
- **decline** → decline the suggestion
- **update** → accept with modifications (e.g., "accept but change severity
  to SEV-3")

If the user ignores the suggestion and continues with something else, don't
action it.

**Step 3: Action the suggestion**

Send a follow-up `ask_incident` call using the same `session_id`, with a
message like:

- "accept suggestion 01HXYZ123ABC456DEF"
- "decline suggestion 01HXYZ123ABC456DEF"
- "update suggestion 01HXYZ123ABC456DEF, change severity to SEV-3"

## Division of Labor

**You (the AI agent)**: Analyze incident data, understand code, identify
what went wrong, draft updates.

**Backend agents**:
- `ask_incident` — Post official incident updates, change status/severity,
  create actions/follow-ups, assign roles.
- `ask` — Answer organisation-level questions (on-call, catalog, schedules).

**Use `incident_message`** for sharing your own analysis. **Use the agent
tools** for actions and queries only the backend can perform.

## Pull Requests

When an incident is pinned, add the following footer to pull request
bodies. incident.io picks this up and links the PR back to the incident
automatically. Use `incident_pin()` to get the current incident ID.

```
> *🤖 Generated with incident.io as part of [INC-12345](https://app.incident.io/~/incidents/12345)*
```

## Tips

1. **Check current incident** — If user says "my incident", use
   `incident_pin()` to check what they're pinning
2. **Pin first** — Use `incident_pin` to set your active incident
   before reading files
8. **Expand @incident requests** — The backend agent can't see your
   session. Translate the user's request into a self-contained question
   with the relevant details from your session

## Example Session

**When user says "help with my incident":**

```
1. incident_pin() → Check if already pinning an incident
2. If pinning INC-12345, use incident_show to get details
3. If not pinning, use escalations_list to find incidents
```

**Full workflow:**

```
1. identity_get → Get your user identity for attribution
2. incident_pin() → Check currently pinned incident, OR
   escalations_list → Find incidents you were paged for
3. incident_pin(incident_id="INC-12345") → Set as active
4. ask_incident(incident_id="INC-12345", question="Summarise this incident") → Get details
5. incident_message(INC-12345, "I've reviewed...") → Post update
```

## Troubleshooting

- **Authentication errors (401/403):** Prompt the user to reauthenticate in
  the incident.io macOS app
- **404 Not Found:** Verify the incident ID exists
- **Backend MCP unavailable:** Local tools still work; backend tools like
  `ask_incident` require connectivity
