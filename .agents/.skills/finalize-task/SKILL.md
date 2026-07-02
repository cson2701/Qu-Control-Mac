---
name: finalize-task
description: Finalize work on the current branch by marking the matching issue row as `Done` in `ISSUE_TRACKER.md`, then pushing the branch and creating a pull request for this repository. Use this skill when the user asks to finalize a task, push a branch, open a PR, or push and create a PR. Always use the repository helper `./scripts/push.sh` exactly as provided instead of manually running `git push` or `gh pr create`.
---

# Finalize Task

Use this workflow whenever the user wants to push the current branch and create
or open a pull request for this repository.

## Required behavior

1. Review the current repository state before pushing:

```bash
git branch --show-current
git status --short
```

1. Require a clean working tree before pushing. If `git status --short` shows
   any changes, ask the user whether they want to commit first.
1. If the user says yes, load the `github-issue-commit` skill, create the
   needed commit or commits, then return to this workflow and continue only
   after the working tree is clean.
1. If the user does not want to commit, stop and do not run the push helper.
1. Confirm the current branch is not `main`. If it is `main`, stop and tell the
   user the helper script refuses to create a PR from `main`.
1. If the repository root contains `ISSUE_TRACKER.md`, update the matching row
   for this issue to `Done`.
   Match by GitHub issue number first.
   If the row is missing, warn the user and continue.
   If the file is absent, skip this step silently.
1. If updating `ISSUE_TRACKER.md` changes the working tree, commit that change
   before pushing. If other issue-related changes are already pending, include
   the tracker update in the same final commit rather than creating a redundant
   extra commit.
1. Run the repository helper exactly as provided:

```bash
./scripts/push.sh
```

Do not replace this with manual `git push`, `gh pr create`, or `gh pr view`
commands unless the script is missing or broken.

## Notes

- `./scripts/push.sh` pushes the current branch to `origin`, creates the PR with
  `gh pr create -f`, and opens the resulting PR in the browser.
- If the script fails because of authentication, network, or GitHub CLI access,
  report the failure clearly and include the failing step.
- Do not run `./scripts/push.sh` with a dirty working tree.
- When a commit is needed first, hand off to `github-issue-commit` rather than
  inventing a separate commit workflow.
- The tracker must be marked `Done` before pushing and PR creation so the PR
  includes the finalized tracker state.

## Reporting

After running the script, report:

- the branch that was pushed
- whether PR creation succeeded
- the PR URL if available
