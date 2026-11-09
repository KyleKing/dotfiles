# Challenging bot findings

A bot's finding is a claim to check, not an instruction.
Watch Doggo (HQ, on irm, hq, and account-manager) and CodeRabbit are confidently wrong
often enough that applying a prompt verbatim regresses code.
A person's review gets more trust and the same check.

Pushing back is how the reviewer improves.
A specific reply in the thread usually makes Watch Doggo stand down, and the reply also
feeds its review metrics.
Agree only with what you verified, and when a finding is valid, fix the whole class.

## Judge each finding

1. Is the code in this PR's diff?
    A finding on unchanged code is an escalation (Step 3), not this PR's fix
1. Can you state the input, caller, or interleaving that breaks?
    If not, it is not real yet
1. Does the guard it asks for protect a case that cannot happen?
    Check the callers and the types.
    An error path for an impossible state is complexity, so decline it
1. Does it ask for tests of declarative code (config, IaC, a schema) or of behavior a
    real test already covers?
    Decline
1. Does it add abstraction, pinning, or a flag where deleting code would do?
    Counter with the simpler change
1. Is it security-shaped?
    A concrete path to data loss or exposure is real.
    A hypothetical with no threat beyond "external content is data" is theater, so name
    the missing threat in the reply
1. Did a thread already settle it, or did the author's answer already cover it?
    One adequate answer closes a finding
1. Does it claim how an outside system behaves (a token claim, an IAM condition key, an
    API shape)?
    Check the vendor's docs or code before any verdict and cite the page.
    On watch-doggo #917 two workers accepted a false claim about GitHub's OIDC token
    and swapped in a condition key AWS never evaluates

## Reply shapes

One sentence after `[AI Bot]: `, with the reason in it.
Cite the line, caller, or doc, and skip "I disagree".

- Declined, vague: `[AI Bot]: This is unnecessary.`
- Declined, specific:
    `[AI Bot]: The only caller, \`load_org\`, passes a validated \`org_id\`, so \`None\` cannot reach here.\`
- Valid, class fixed:
    `[AI Bot]: Moved the org check into \`require_scope\`, so all four routes get it.\`

A finding that merely lacks evidence still gets the reason.
Never answer a thread twice for the same head, because Watch Doggo starts a full round
per reply.

## Reflect on the review each round

After the verdicts, write down in the report:

- what the reviewer raised wrongly (the failure kind: unchanged code, impossible case,
    declarative-code tests, security theater, a reopened settled thread, added
    complexity)
- what it missed, meaning a real problem on a PR it approved, or open threads under an
    approval

Round limits and merge rules live in the `hq-review-merge` skill.

A Watch Doggo miss or false positive is a product defect.
Under `pr-pass`, record it in `ai-output/hq-audit/<date>/`.
Otherwise list it under `hq_findings` in the report, each with the PR, the thread, and
one line of evidence, so the user can open an hq issue.
Fix the review loop, not only this PR.
