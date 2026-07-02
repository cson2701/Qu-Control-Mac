# Qu Controller Issue Tracker

This file tracks the initial migration work for the Swift/Xcode version of Qu Controller.

## Local Skill Access

The following repo-local skills are available for task and issue creation:

- `create-issue` at `.agents/.skills/create-issue/SKILL.md`
- `github-issue-start` at `.agents/.skills/github-issue-start/SKILL.md`
- `github-issue-commit` at `.agents/.skills/github-issue-commit/SKILL.md`
- `finalize-task` at `.agents/.skills/finalize-task/SKILL.md`

## Current Priority

1. [#1 Create the UI and baseline code](https://github.com/cson2701/Qu-Control-Mac/issues/1)
2. [#2 Communicate with the mixer](https://github.com/cson2701/Qu-Control-Mac/issues/2)

These are the first delivery tasks for this project:

- Issue `#1` establishes the SwiftUI app structure, screen layout, domain model, and mock controller behavior.
- Issue `#2` ports the mixer transport and protocol handling so the app can talk to the physical Qu mixer.

## Task List

| Status | Task | Title | Notes |
|--------|------|-------|-------|
| Todo | [#1](https://github.com/cson2701/Qu-Control-Mac/issues/1) | Create the UI and baseline code | Port the Kotlin app structure to SwiftUI, including the Main LR fader screen, baseline models, state, and mock controller |
| Todo | [#2](https://github.com/cson2701/Qu-Control-Mac/issues/2) | Communicate with the mixer | Reimplement the Qu TCP/MIDI connection layer in Swift and wire it into the baseline app |

## Suggested Execution Order

1. `#1` Create the UI and baseline code
2. `#2` Communicate with the mixer

## Notes

- `#1` should land first so the app can be exercised without hardware.
- `#2` should preserve the behavior of the Kotlin `QuTcpMidiController.jvm.kt` implementation where practical.
- The initial migration tasks are now tracked as GitHub issues `#1` and `#2` in `cson2701/Qu-Control-Mac`.
