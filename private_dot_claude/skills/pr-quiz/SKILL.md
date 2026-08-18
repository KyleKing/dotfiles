---
name: pr-quiz
description: Generate a short multiple-choice quiz that tests whether someone actually understands a PR's core behavior and edge cases, rather than just skimming it. Invoke explicitly with a PR number, URL, or branch.
argument-hint: "[PR number, URL, or branch; defaults to the current branch's PR]"
disable-model-invocation: true
---

# PR quiz

A quiz posted to a PR to check comprehension before merge, not a review of the code
itself.
Keep it quick: read the diff, ask a handful of sharp questions, then use the
misses to find out whether the code is wrong or the question was.

## Gather the change

Resolve the target with `gh`:

- A number or URL: `gh pr view <target> --json title,body,files` and `gh pr diff <target>`
- No argument: same commands against the current branch's PR

Read the full diff, not just the description.
The quiz is about what the code does, and
a PR body can be stale or aspirational.

## Write the questions

Write 2 to 10 questions, scaled to the size of the diff.
A 20-line fix might earn 2; a
migration or a new code path earns closer to 10.
Each question targets one specific
behavior, edge case, or invariant the diff introduces or changes: a boundary condition,
an error path, a state transition, an interaction between two changed pieces.
Skip
anything answerable from the PR title or a variable name; that tests reading, not
understanding.

Anchor every stem in a concrete scenario ("if X calls this with an empty list" rather
than "what does this function do"), so answering requires tracing the actual logic
instead of recognizing the description.

Give each question exactly 3 options. Three plausible options beat four or five where
the extra choices are padding, and padding is exactly what a quick quiz doesn't have
room for.
Each wrong option should be wrong for a specific, real reason: the pre-change
behavior, the most common misreading of the diff, an adjacent edge case the code
actually handles differently.
Never write a throwaway option nobody would pick.

Keep all three options within a word or two of each other in length and phrasing.
A
noticeably longer or more hedged option is a free tell, and the whole point is that
guessing shouldn't work.
No "all of the above," no "none of the above," no absolute
words like "always" or "never" used as a shortcut to the right answer.

## Format

Post it as one markdown block, numbered questions with lettered options.
Put the answer
key and a one-line explanation per question inside a single collapsed section at the
end, citing the specific file and line the answer turns on, so nothing above the fold
gives it away:

```markdown
1. If `parseConfig` receives a file with no `version` key, what does it return?
   a. Raises `ConfigError` immediately
   b. Falls back to the default config with a logged warning
   c. Returns `None` and lets the caller decide

<details>
<summary>Answers</summary>

1. b — `config.py:42` sets the default before validation runs; there's no raise
   or `None` path in this function.

</details>
```

Write every question and explanation to the mechanical rules in `writing-voice`: no em
dashes, no bolded lead-in bullets, no filler.

## Run it and diagnose misses

Post the questions without the answers and wait.
When answers come back, reveal the key
and, for every wrong one, ask directly which of these it was:

- the code doesn't do what the question assumed, meaning the diff has a real gap worth
    fixing before merge
- the question was ambiguous, poorly scoped, or testing something the diff didn't
    actually make clear

Don't guess which one it is. A miss is only useful once you know whether it points at
the code or at the quiz, so ask, and treat the PR as unverified until the answer comes
back one way or the other.
