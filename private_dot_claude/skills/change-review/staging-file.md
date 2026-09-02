# Staging a review before posting

Write a local `pr-<number>-review-comments.md` for the user to proofread and edit
directly — a working draft, not a finished artifact.

## The blockquote rule

Blockquote means post-facing; everything else is for the user's eyes only.
Keep the
split strict so the posted text stays unambiguous.

## Shape

Open with an unquoted orientation header: PR title, branch and base, the commit you
verified anchors against, test commands that actually ran with results, suites you
couldn't run and why, and whether any bot reviewed the PR.
A few lines — it shows how
much of the review is proven versus read.

Group items under "New findings" and "Bot-thread replies", by file in diff order.
One
unquoted meta line per item, directly above its blockquote:

```
`file:line` — severity — action
```

where action is `new comment`, `reply to <bot> thread`, or `general review comment`.
The blockquote holds only the exact text to post — no rationale, no extra prose.

No numbered IDs, no status field; the user deletes what they don't want.

## Markers

`[TODO: ...]` is the user's own edit requesting a revision before the next pass.
`[AI: ...]` flags an open decision or question, so the two never collide.

## Declined items

A thread not worth replying to (stale, or a nit not worth a comment) gets a meta line
only, no blockquote, action `skip (<short reason>)`:

```
`file:line` — nit — skip (style-only, not applying)
```

Visible as considered-and-declined, not erased.

## Bot-thread replies

Put a bare permalink to the comment being replied to on or just above its meta line.
Don't paste the bot's comment or diff inline — the meta line's `file:line` is enough
context for a new comment.

The user sometimes opens a bot-thread blockquote with `^`
(`> ^I think this is valid...`), marking third-person reference to the author rather
than addressing them.
Bot threads only, never human ones, and only selectively — preserve it where it appears,
don't add or remove it yourself.

## Re-editing on a later pass

Once the user hand-edits a comment, treat it as settled — don't re-polish it against
Voice rules, which govern what you draft, not what they've already written.
Small,
clearly-needed edits (a changed anchor, a factual correction) are fine; don't rewrite
the sentence.

## Closing the file

End with a **Proposed PR comment**: one fully-blockquoted line, following "The
review-level comment" in `SKILL.md` — default to a short varied acknowledgment, a real
paragraph only for a finding that couldn't get a `file:line`.
