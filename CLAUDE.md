# Tony

How Claude works on Tony, an iOS 27 app for iPhone and iPad in English and French. What to build lives in Notion and the issues; the architecture in the Solution Document. Part of the AHDH Claude project.

- Project: https://claude.ai/cowork/project/01a1cafa-136f-77e7-947e-4dbd55343a28
- Docs (Notion): https://app.notion.com/p/Tony-42281c5914d280518492fb08cb48c089
- Architecture: [Solution Document](https://app.notion.com/p/42281c5914d2816dbc5dfe2fa2e7e05a)
- UI and UX: [UX guidelines](https://app.notion.com/p/42381c5914d281c8a36bccefb5b83e1b), then Apple's HIG
- Figma (colours, type, components, wireframes): https://www.figma.com/design/VKMc5C6tBa8W1gemsrrZAc

## Writing

- Replies to Matteo and PR descriptions: short, to the point. No reasoning or background unless asked.
- PR description: what changed (bullets), tests run, device checks left, questions. Copy the chunk's "Done when" with one line of proof each. Screenshots for visual changes.
- Report at completion: what changed, tests run, tests not run and why (device checks included), decisions for Matteo.

## Project

- One Xcode project, `Tony.xcodeproj`, edited in Xcode, no generator. Folders `<Target>/` and `<Target>Tests/` are synchronized: a file added to a folder joins its target.
- One package: MemberwiseInit 0.6.0 (exact). Structs whose init only assigns use `@MemberwiseInit(.public)` (`TonyCore`, `TonyUIModels`, `TonyPresentation`).
- A test target links every framework its tests import.
- Frameworks load resources with `#bundle`, never `Bundle.main`.
- App and extension `Info.plist` and `.entitlements` are in `Configuration/`.
- Shared schemes: `TonyApp` (app, UI tests), `TonyUnitTests`, `TonyUIKit` (previews).
- App group: `group.com.mt81.tony`.
- `TonyDebug/`: debug-only source compiled into app and extension. Debug-only text is English, not translated.
- Debug builds take the launch argument `-now 08:00` to freeze the clock today.

## Commands

| Command | Does |
| --- | --- |
| `make test` | Import check, then `TonyCore`, `TonyStore`, `TonyPresentation` unit tests |
| `make test-ui` | `TonyAppUITests` in the simulator |
| `make build` | Builds the app for the simulator |
| `make run` | Builds, installs, launches in the simulator |
| `make clean` | Deletes build output |

Outside the Makefile: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, and `xcodebuild -skipMacroValidation`.
One suite: `xcodebuild test -project Tony.xcodeproj -scheme TonyUnitTests -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -skipMacroValidation -only-testing:TonyCoreTests/<suite>`.

## Decisions

- Matteo owns architecture. Follow the Solution Document and the existing targets, technologies and conventions.
- His approval is needed to add, replace or restructure patterns, technologies, dependencies, integrations or targets, and to change the Solution Document's decisions.
- For those, bring problem, options, tradeoffs, recommendation; wait.
- Local implementation choices within the patterns are yours; don't ask about them.
- Flag architectural risks outside the task; don't fix them unasked.
- Ask Matteo when requirements are ambiguous, or for legal, financial or external consequences (App Store, TestFlight, signing, paid services).
- New UI (screen, sheet, component, new state or section) is drawn first as a Figma wireframe beside the existing frames and approved by Matteo. Build only what he approved.
- Figma costs credits: read single nodes, one screenshot after composing and one after a fix, few `use_figma` calls, copy existing frames and components. No Figma AI generation without asking.

## Git

- `main` is the only long-lived branch. Never commit or push to it; everything goes through a PR.
- Branch from an up-to-date `main`: `c03-cadence-and-neglect` for a chunk, plain kebab-case otherwise.
- Each branch in its own worktree, so chunks run in parallel: `git worktree add worktrees/<branch> -b <branch> origin/main` (`worktrees/` is ignored). Build output stays per worktree. Parallel test runs use different simulators: `make test SIMULATOR='iPhone 18 Pro Max'`. After the merge, `git worktree remove worktrees/<branch>`.
- One chunk, one PR, closing its issue (`Closes #3`). Start a chunk only after its dependencies are merged.
- Catch up by rebasing onto `main`. Force-push only your own branch, `--force-with-lease`.
- Merge with `gh pr merge --squash`, one brief subject, no body. No merge commits. Delete the branch after.
- Small commits, imperative subject. Commit only source and `Tony.xcodeproj`, never build output, `xcuserdata/` or `.DS_Store`.
- Keep PRs reviewable; split unrelated changes.

## Before every push

Never push red.

1. `make test` passes.
2. `make build`: no errors, no warnings.
3. App changes: `make run` and `make test-ui`.
4. Visual changes: look at English and French, iPhone and iPad, largest Dynamic Type.
5. Read the diff: no secrets, debug code, leftovers or unrelated changes.

- Never claim a test passed unless it ran. Say which couldn't run and why.
- A failing test means fixing the code, or the test if behaviour changed on purpose. Never skip, loosen or delete one. Known gaps use `withKnownIssue` with a reason.
- Claude can't run on a real iPhone. `needs device` chunks aren't done until Matteo checks them: list what to check, never report it as verified.

## Code

- First read the chunk's issue, its dependencies and the code around the change.
- Before code that calls a system framework or external service (EventKit, HealthKit, FoundationModels, WidgetKit, MET Norway), check names, types and behaviour in its official documentation. The documentation wins over the issue; flag the conflict.
- Tests first. Write the chunk's tests from the spec, compiling and failing, then show Matteo a table: # · suite · test · happy, edge or error. Commit them and start the implementation only after he approves.
- Fix causes, not symptoms. Stay in scope; flag other problems.
- Simplest thing that satisfies the chunk. No abstractions, helpers, configuration or building ahead without a need. Reuse patterns, don't duplicate, don't refactor unrelated code, don't optimise without a measured problem.
- Full-word names (`completion`, `busyInterval`); only `x`, `y`, `_` short. Swift API Design Guidelines.
- Comments only for the surprising.
- No warnings. `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency` only with a one-line reason.
- No force unwraps, `try!` or `fatalError` in shipping code. Tests may `#require`.
- Swift Testing everywhere except the XCTest UI tests. Planner behaviour: fixtures and table-driven tests. New behaviour comes with a test.
- No test-only code in shipping code: no test branches, hooks or flags. Tests isolate through fakes of the `TonyCore` protocols, kept in the test targets.
- Test each layer against fakes of the one below. Don't test infrastructure: SwiftData schema, migrations, `Info.plist`, framework wiring.
- Fixtures use invented data, never Matteo's real records.
- No hardcoded user-facing text: String Catalog, English and French, templates included. A missing string is a bug.
- Model prompts: one English `.txt` per prompt in `TonyPresentation/Prompts`, answering in `{language}` from the passed locale. Parsing and prompts checked in both languages.
- No hardcoded colours, fonts, sizes or radii: `TonyUIKit` tokens and components, from Figma.
- Shell scripts and Makefile: named variables, one action per line.
- Prefer Apple frameworks. Otherwise bring Matteo library candidates (reliability, ease, adoption, maintenance, licence, recommendation); he picks.
- Matteo approves every new dependency, external service, network request, entitlement, capability, permission prompt or background mode. Pin exact versions. Usage descriptions in both languages.
- No secrets, certificates or profiles in the repo or logs.
- Flag misleading text instead of inventing fixes.
- When a rule changes, update this file in the same PR; when an architecture decision changes, the Solution Document.
