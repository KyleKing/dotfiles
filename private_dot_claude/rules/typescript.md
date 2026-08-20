---
paths:
  - '**/*.ts'
  - '**/*.tsx'
  - '**/*.js'
  - '**/*.mjs'
  - '**/deno.json'
  - '**/deno.jsonc'
  - '**/biome.json'
  - '**/biome.jsonc'
---

# TypeScript / JavaScript

The runtime is Deno, chosen by ADR (`tlr/adr/0001-deno-over-python.md`).
No Node,
no Bun, no bundler, no front-end framework — vanilla ES modules and CSS, so pure
logic stays testable without a build step.

## Settings that are already decided

`compilerOptions`: `strict: true`, `lib: ["dom", "deno.ns"]`, `skipLibCheck: true`.

`fmt`: `semiColons: false`, `lineWidth: 120`, `indentWidth: 2`, `useTabs: false`,
`proseWrap: "preserve"`.
A Go repo using Biome for its JS (recipes) is the
exception: tabs, width 100, double quotes, semicolons always.
Follow the repo.

Import map aliases: `@/` to `./src/`, `~/` to `./shared/`.

## Two linters, one formatter

Biome runs alongside `deno lint` with `"formatter": {"enabled": false}` — deno fmt
owns formatting — and `organizeImports: "off"`, because dprint keeps
`module.sortImportDeclarations: "maintain"`.

Biome is the one most often missed. It fails the hook on rules `deno lint` does not
carry (`useTemplate`, `noControlCharactersInRegex`), so run it before assuming a
change is clean.

Rules set to `error`: `noUnusedVariables`, `noUnusedImports`,
`noUnusedPrivateClassMembers`, `useConst`, `useImportType`.
`noExplicitAny` is off.

## Layout

Tests are colocated as `*_test.ts` next to their source; benches are `**/*_bench.ts`.
Run tests with `--check=all`.

Browser code lives in `web/lib/*.js` as plain ES modules importable by both the
browser and Deno tests.
Keep pure logic there free of I/O so tests drive it without
a network.

Isomorphic code goes in `shared/` and is transpiled to `public/shared/` by
`scripts/build-shared.ts`.

## Testing

`@std/assert` with `deno test` for units, Playwright for e2e.
The e2e fixture fails
any test that produced a browser console error, so a console error is a test
failure, not noise.
