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
| Done | [#1](https://github.com/cson2701/Qu-Control-Mac/issues/1) | Create the UI and baseline code | Port the Kotlin app structure to SwiftUI, including the Main LR fader screen, baseline models, state, and mock controller |
| Done | [#2](https://github.com/cson2701/Qu-Control-Mac/issues/2) | Communicate with the mixer | Reimplement the Qu TCP/MIDI connection layer in Swift and wire it into the baseline app |
| Done | [#4](https://github.com/cson2701/Qu-Control-Mac/issues/4) | Add the ability to shut down the mixer | Add a confirmed shutdown action for a connected live mixer |
| Done | [#8](https://github.com/cson2701/Qu-Control-Mac/issues/8) | Add support for multiple visible mixer channels with persisted layout | Expand the screen beyond Main LR and save the visible layout locally |
| Done | [#9](https://github.com/cson2701/Qu-Control-Mac/issues/9) | Add a native menu bar mixer control surface | Show selected horizontal sliders from a menu bar popup that dismisses on focus loss |
| Done | [#10](https://github.com/cson2701/Qu-Control-Mac/issues/10) | Set custom app and menu bar icons | Add proper icon assets for the app bundle and menu bar extra |
| Done | [#5](https://github.com/cson2701/Qu-Control-Mac/issues/5) | Explore auto-discovering the mixer on the local network | Assess whether the app can find the mixer IP automatically |
| Done | [#14](https://github.com/cson2701/Qu-Control-Mac/issues/14) | Refine connection-first UI flow | Show a dedicated connection screen until the mixer connects |
| Done | [#17](https://github.com/cson2701/Qu-Control-Mac/issues/17) | Add settings items | Add local task tracking for the settings items issue |
| Done | [#18](https://github.com/cson2701/Qu-Control-Mac/issues/18) | Add a debug-only mock connection toggle | Add a debug-only mock toggle and stop discovery immediately when mock mode is enabled |
| Done | [#20](https://github.com/cson2701/Qu-Control-Mac/issues/20) | Add more connection and app behavior settings | Follow-on settings ideas beyond the initial settings window |
| Done | [#22](https://github.com/cson2701/Qu-Control-Mac/issues/22) | Add per-channel mute controls | Add mute state and toggle controls for visible mixer channels |
| Done | [#23](https://github.com/cson2701/Qu-Control-Mac/issues/23) | Add live channel metering | Implemented lightweight per-channel signal indicators instead of full meters, with a settings toggle that disables monitoring when off |
| Todo | [#26](https://github.com/cson2701/Qu-Control-Mac/issues/26) | Add USB MIDI support alongside TCP | Add USB MIDI as an alternative mixer transport |
| Done | [#25](https://github.com/cson2701/Qu-Control-Mac/issues/25) | Menu bar icon won't show when turning on the switch in settings | Menu bar icon only appears on app launch when the setting was already enabled |
| Done | [#31](https://github.com/cson2701/Qu-Control-Mac/issues/31) | Add relay mode that proxies a single mixer connection to remote clients | Add Mac-hosted relay mode for remote clients |

## Suggested Execution Order

1. `#1` Create the UI and baseline code
2. `#2` Communicate with the mixer
3. `#4` Add the ability to shut down the mixer
4. `#8` Add support for multiple visible mixer channels with persisted layout
5. `#9` Add a native menu bar mixer control surface
6. `#10` Set custom app and menu bar icons
7. `#5` Explore auto-discovering the mixer on the local network

## Notes

- `#1` should land first so the app can be exercised without hardware.
- `#2` should preserve the behavior of the Kotlin `QuTcpMidiController.jvm.kt` implementation where practical.
- The initial migration tasks are now tracked as GitHub issues `#1` and `#2` in `cson2701/Qu-Control-Mac`.
