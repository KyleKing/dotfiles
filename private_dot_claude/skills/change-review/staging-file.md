# Staging a review before posting

Write a local `pr-<number>-review-comments.md` for the user to proofread and edit
directly.
It is a working draft, not a finished artifact.

## The blockquote rule

Blockquote means post-facing. Non-blockquote means for the user's eyes only.
Everything inside a blockquote is verbatim text a reader will see; everything outside
one (meta lines, orientation header, context snippets) helps the user review and never
ships.
Keep the split strict so the file can be skimmed and the posted text is unambiguous.

## Shape

Open with an unquoted orientation header: the PR title, the branch and base, the commit
you verified anchors against, the test commands that actually ran with their results,
the
suites you could not run and why, and whether any bot reviewed the PR.
Keep it to a few lines. It exists so the user can tell how much of the review is proven
and how much is reading.

Then group items under "New findings" and "Bot-thread replies", each grouped by file in
diff order.

One unquoted meta line per item, directly above its blockquote:

```
`file:line` — severity — action
```

where action is `new comment`, `reply to <bot> thread`, or `general review comment`.

The blockquote holds only the exact text to post.
No rationale, no extra prose — the comment text already carries whatever "why" belongs
on a peer.

No numbered IDs and no status field; the user deletes items they do not want.

## Markers

`[TODO: ...]` is reserved for the user's own edits requesting a revision before the next
pass.
Use `[AI: ...]` to flag an open decision or ask a question, so the two never collide.

## Declined items

A thread not worth replying to (already stale, or a nit not worth a comment) gets a meta
line only, no blockquote, with action `skip (<short reason>)`:

```
`file:line` — nit — skip (style-only, not applying)
```

That keeps it visible as considered-and-declined rather than erased.

## Bot-thread replies

Put a bare permalink to the comment being replied to on, or just above, its meta line so
the user can open the original.
Do not paste the bot's comment or its diff inline; that bloats the file.
New comments need no context block — the meta line's `file:line` is enough.

The user sometimes opens a bot-thread blockquote with `^`
(`> ^I think this is valid...`), marking that the reply is about the author in the third
person rather than addressed to them.
This is only ever used on bot threads, never a human's, and only selectively.
Preserve it where it appears; do not add or remove it on your own judgment.

## Re-editing on a later pass

Once the user has hand-edited a comment's text, treat it as settled.
Do not re-polish it against the Voice rules — those govern what you draft, not what the
user has already written.
Their phrasing may deliberately break them (a capitalized "OR", an "etc.") as a personal
tick, not an error to fix.
Small conservative edits are still fine when clearly needed (a changed anchor, a factual
correction); do not rewrite the sentence wholesale.

## Closing the file

End with a **Proposed PR comment**: one fully-blockquoted line, so the user reads
exactly what a reader sees.
Default it to a short, varied acknowledgment (`LGTM`, `LGTM!`, `Looks good`, `Looks good
to me`, `Looks good!`, `Yes!`), not a summary of the findings above.

Write a real paragraph here only when a "New findings" item above could not get a
`file:line` (outside the diff, or too broad for one location) and still needs surfacing.
Even then, keep it to that finding, not a re-summary of everything already inline.
