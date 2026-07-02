---
name: create-issue
description: Create a GitHub issue for this repository and record it in the local ISSUE_TRACKER.md file. Use this skill when the user asks to create a GitHub issue, add a new task, or write work into issues for this repo. Always create the GitHub issue first, then add a matching `Todo` row to `ISSUE_TRACKER.md`.
---

# Create Issue

Use this workflow whenever the user wants a new GitHub issue created for this
repository.

## Required behavior

1. Confirm the issue scope from the current conversation. If the task is too
   vague to write a usable issue, ask one concise clarifying question.
1. Draft a concrete issue title and body before creation.
1. Create the issue with `gh issue create`.
1. Read back the created issue number and URL.
1. If the repository root contains `ISSUE_TRACKER.md`, add a new `Todo` row to
   the `## Task List` table for the created issue.
1. Report the created issue number, URL, and whether the tracker was updated.

## Issue creation workflow

Use `gh` directly for this repository:

```bash
gh issue create --title "<title>" --body "<body>" --label "<label>"
```

If labels are not specified by the user, prefer the most appropriate existing
repository label rather than inventing a new one.

After creation, capture at minimum:

```bash
gh issue view <issue_number> --json number,title,url,labels
```

## ISSUE_TRACKER.md update rules

When `ISSUE_TRACKER.md` exists:

1. Find the `## Task List` markdown table.
1. Append a row in this format:

```md
| Todo | [#<issue_number>](<issue_url>) | <issue_title> | <short note> |
```

1. Match the existing table style and spacing closely.
1. Do not create a duplicate row if the issue already exists in the tracker.
1. Use a short note only when one is obvious from the request. Otherwise use
   `New task`.

If the table is missing or malformed, warn the user and stop before making a
guessing edit to the tracker.

## Suggested execution order

If the new issue is clearly part of the active roadmap and the ordering is
obvious, update the `## Suggested Execution Order` list too.

Rules:

- Only add the new issue there when its place in the order is clear.
- If ordering is ambiguous, leave that section unchanged.
- Do not renumber or rewrite the whole roadmap unless the user asked for it.

## Safety rules

- Do not touch global skills under `~/.agents/skills`.
- Do not create issues in another repository unless the user explicitly says to.
- Do not edit unrelated tracker rows.
- Do not silently skip the tracker update when `ISSUE_TRACKER.md` exists. Either
  update it or tell the user exactly why it could not be updated.

## Reporting

After completion, report:

- the issue number
- the issue title
- the issue URL
- whether `ISSUE_TRACKER.md` was updated
