---
paths:
  - '**/*.html'
  - '**/*.vto'
  - '**/*.jinja'
  - '**/*.j2'
  - '**/*.templ'
---

# HTML and templates

Server-rendered semantic HTML with htmx for interactivity.
htmx was kept over
Datastar and Alpine by ADR (`app-template/docs/adr/0001-hypermedia-library-choice.md`),
which names three patterns to reach for first: `hx-swap-oob`, `hx-swap` modifiers
(`settle:`, `show:`), and `hx-sync`.

Favor server-side rendering over client-side htmx and JavaScript when all else is
equal.

## Accessibility

This is tested, not asserted. axe-core runs against `wcag2aa` plus `color-contrast`
on every page, and the suite deliberately clicks chips and checkboxes first so
selected-state colors land in the scan.

Standing markup habits:

- A skip link (`<a href="#main-content" class="skip-link">`) with
    `<main id="main-content" tabindex="-1">`
- Explicit landmark roles (`<header role="banner">`), `aria-current` on nav,
    `aria-label` on icon-only controls, `aria-hidden="true"` on decorative glyphs
- `role="status" aria-live="polite"` on toasts and result counts, `aria-pressed` on
    toggles
- Forms use `<fieldset>`/`<legend>`, `<label for=…>`, `autocomplete`, and `maxlength`
- Prefer native `<details>` over a JS toggle for browser-native keyboard and ARIA
    behavior.
    Ship it **open** and close it with JS: a closed `<details>` hides its
    body with `content-visibility` on `::details-content`, which author CSS cannot
    force back open
- Replace `window.confirm()` by intercepting `htmx:confirm`, so delete stays
    confirmable with keyboard and screen reader focus alone

Mobile shell: `viewport-fit=cover` with `env(safe-area-inset-*)` padding, paired
`theme-color` meta per color scheme, and a `manifest.webmanifest` with
`display: standalone` — without it iOS opens every navigation in an in-app browser
overlay.

## Vento (`.vto`)

Split into `src/templates/{layouts,pages,partials}/`.
The engine pins
`vento({ autoescape: true })`, and autoescaping is treated as a security property:
there is a dedicated XSS e2e spec proving it.
Pass pre-rendered content through
`|> safe` explicitly (`{{ content |> safe }}`) and never disable autoescape to avoid
doing so.

Pages render through one `renderPage(pageTemplate, data, title, c)` helper wrapping
`layouts/base.vto`.
A new page means a `.vto` under `pages/` plus a registration in
`src/routes.ts`.

## Jinja2 (`.html.jinja`)

Files carry the double extension. Every template opens with a types-for-jinja
`{#def #}` signature block declaring its imports and parameter types:

```
{#def
from yak_shears._templates import YakInfo, SortBy
yaks: list[YakInfo]
current_page: int
total_pages: int
-#}
```

A parameter with a default is declared as `current_route: str = "habits"`, and may
sit anywhere in the header because every generated parameter is keyword-only.
Use a
default for a value the caller should not have to know (the route name a page passes
to `base.html.jinja`) rather than supplying it from Python.

`uv run types-for-jinja generate` writes a stub per template; `ty check` on those
stubs, wrapped by `types-for-jinja remap` so its output and exit code point back at
the template, runs as a pre-commit step, so an undeclared parameter fails the hook.
Every template gets its typed render function from `uv run types-for-jinja wrapper`,
which writes into `yak_shears/_templates/_generated/`.
Both directories are build
artifacts: gitignored, rebuilt by `mise run generate`, never hand-edited.
Nothing
renders through an untyped `**context` helper, because a renamed template parameter
goes uncaught through one.
`render_error` wraps its generated function only to set a
status code.

A module that defines a view model a template declares must not also call that
template's render function: the generated wrapper imports the model at runtime, so
the pair closes an import cycle.
Keep the handlers in a separate module.

Template comments (`{# … #}`) carry browser-quirk rationale; CSS and Python
rationale belongs in those files.

## templ (`.templ`)

Generated Go (`templates_templ.go`) is committed.
Edit the `.templ` for structure and
`build.go` for content processing, then run `mise run format`, which chains
`templ generate`, `templ fmt`, and `go fmt` before lint and test.
Never hand-edit
the generated file.

Components are small page-shape functions (`page`, `recipePage`, `dirIndexPage`,
`homePage`) with a `pageType` discriminator.

## Copier templates

A `.jinja` file inside a copier template is a different thing from a runtime
template.
Wrap anything that must survive into the output in `{% raw %}`, use
`_skip_if_exists` for files a generated project takes over, and commit rendered
output under `.ctt/` so a template change reviews as a diff of generated projects.
