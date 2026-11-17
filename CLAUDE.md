# Tony

Tony is an iOS 27 app (iPhone and iPad, English and French) that plans the day around recurring tasks, goals and the calendar. The work is cut into 28 chunks, C01 to C28, tracked as GitHub issues #1 to #28.

- Build chunks: https://claude.ai/artifact/YF6oBu6Zf1ZaBBcYMMMjUL
- Solution document (decisions D1 to D14, spikes S1 to S5): https://claude.ai/artifact/2tZQjv5SA6uZzWBjjmWnkU
- Figma file (colours, type styles, components, wireframes): https://www.figma.com/design/VKMc5C6tBa8W1gemsrrZAc

## Project layout

| Target | Contains | Verified by |
| --- | --- | --- |
| `TonyCore` (framework) | Domain model, cadence, context builder, planner, consistency, protocols | Unit tests (`TonyCoreTests`) |
| `TonyStore` (framework) | SwiftData models and the `Repository` implementation, shared by the app and the extension | Unit tests (`TonyStoreTests`), in memory |
| `TonyUIModels` (framework) | The data models of controls and components, in plain Swift | Through the previews of `TonyUIKit` |
| `TonyUIKit` (framework) | The reusable UI, on its own: the SwiftUI controls and components that draw the `TonyUIModels` data models, the colour, type, spacing and radius tokens, fonts and artwork | Xcode previews, and the gallery in the simulator (`-gallery` launch argument, debug builds) |
| `TonyPresentation` (framework) | The glue between business and UI, with the `Store` and `Feature` protocol; each screen's state, actions, reducer and effects; each screen's data model and the mapping from state to it; presentation strings | Unit tests (`TonyPresentationTests`) |
| `TonyScreens` (framework) | The SwiftUI screens that draw the `TonyPresentation` data models with the components of `TonyUIKit` | Xcode previews |
| `TonyApp` (iOS app) | Wiring and system adapters: creates the stores, puts the screens in the tab bar, and holds the adapters over system frameworks (EventKit) | Simulator (`TonyAppUITests`), then device |
| `TonyWidgets` (extension) | Widget timeline provider, App Intents | Device |

- Everything lives in one Xcode project, `Tony.xcodeproj`, committed and edited in Xcode. There are no Swift packages and no project generator.
- Each target has a folder of the same name at the root (its tests in `<Target>Tests/`). The folders are synchronized with the project: adding a file to a folder adds it to its target.
- A test target links every framework its tests import; a framework does not pass its dependencies on to them.
- A framework finds its own resources with `#bundle` (`Color("Canvas", bundle: #bundle)`), never `Bundle.main`.
- The `Info.plist` and `.entitlements` files of the app and the extension are in `Configuration/`. The frameworks and test targets generate theirs.
- Two shared schemes: `TonyApp` builds and runs the app and runs the UI tests; `TonyUnitTests` runs the unit tests.
- The app and the extension share data through the app group `group.com.mt81.tony`.
- Debug builds have four launch arguments: `-gallery` shows the component gallery, `-calendar` shows the calendar check (calendar access and today's blocks as the planner sees them), `-model` shows the model check (it runs the evaluation set on the on-device model and reports the pass rate, and shows what the widget and the background task noted), and `-now 08:00` freezes the clock at that time today, to see the plan at another hour.
- The app declares the background refresh mode with one task identifier, `com.mt81.tony.refresh`. Until C21 only the debug model check uses it.
- `TonyDebug/` holds debug-only source compiled into both the app and the widget extension.

## Commands

| Command | What it does |
| --- | --- |
| `make test` | Import check, then `TonyCore`, `TonyStore` and `TonyPresentation` unit tests |
| `make test-ui` | Runs the UI tests of `TonyAppUITests` in the simulator |
| `make build` | Builds the app for the simulator |
| `make run` | Builds, installs and launches in the simulator |
| `make clean` | Deletes build output |

The Makefile sets `DEVELOPER_DIR` to Xcode. Outside it, `xcodebuild` and `xcrun simctl` need `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Architecture ownership and decisions

- Matteo owns architecture decisions.
- Follow the established architecture, target boundaries, technologies and conventions.
- Do not introduce, replace or significantly restructure architectural patterns, technologies, dependencies, integrations or target boundaries without Matteo's approval.
- Decisions D1 to D14 in the solution document are taken as written. Changing one needs Matteo's approval.
- Local implementation decisions within established patterns are delegated to Claude.
- For architectural concerns, present the problem, viable options, tradeoffs and recommendation. Wait for approval before implementing changes that require architectural approval.
- Do not ask for approval for routine implementation details already covered by these instructions or established project conventions.
- Flag architectural risks and inconsistencies even when they are outside the requested scope. Do not fix them without approval.

## Architecture rules

- Logic lives in `TonyCore`. It never imports UIKit, SwiftUI, EventKit, HealthKit, WeatherKit, WidgetKit, SwiftData or UserNotifications. `make check-imports` enforces the first four.
- System frameworks sit behind protocols declared in `TonyCore` (`CalendarSource`, `HealthSource`, `WeatherSource`, `LanguageService`, `NudgeScheduler`, `Repository`, `TaskCatalog`). The app provides the real adapters; tests use fakes.
- The planner is deterministic: the current time, calendar and locale are passed in (`plan(..., now:)`), never read from `Date()`, `Calendar.current` or `Locale.current` inside `TonyCore`.
- The on-device model only words and parses. It never decides the plan. Model output is validated against the plan, and every model feature has a template or rule-based fallback.
- The business layer (`TonyCore`) and the views (`TonyUIKit`, `TonyUIModels`, `TonyScreens`) do not know each other. A view never sees a business object such as `TonyTask`: it only sees data models.
- The `TonyPresentation` target is the only one that knows both. Its reducers and mappers turn business objects into data models, and user actions into changes. It imports `TonyUIModels`, never SwiftUI or the views.
- The `TonyScreens` target imports `TonyPresentation` for the screens' data models and `TonyUIKit` for the components. It never imports `TonyCore`.
- `TonyApp` wires the stores to their adapters and shows the screens. `make check-imports` enforces all of these boundaries.

## Screens

Every screen follows one unidirectional pattern, like Redux:

1. A `Store` holds the screen's `State`.
2. The user acts on a view, which calls a closure of its data model. The closure sends an `Action` to the store.
3. `reduce(&state, action)` changes the state and returns `Effect` values. It is pure: no clock, storage or network.
4. The store runs each effect with the feature's `Environment` (repository, catalogue…) and sends back the action that reports its result.
5. `dataModel(state, context)` turns the state into the screen's data model, and the view draws it again.

- Every view takes its own data model: the values it shows, already localised and formatted, and the closures it calls. A button's data model has its title and its action.
- Views decide nothing: no `if` on domain state, no formatting, no strings of their own. They lay out what the data model says.
- A control's or a component's data model lives in `TonyUIModels` and its view in `TonyUIKit`. A screen's data model lives beside its feature in `TonyPresentation` and its view in `TonyScreens`.
- Every view has an Xcode preview with sample data, and so do the tokens (colours, type styles, spacings, radii, artwork). Previews and their sample data are inside `#if DEBUG`; their text is sample data, not translated. A new view comes with its preview.
- Reducers, effects and data models are tested in `TonyPresentation` with fakes; UI tests only check that the screens are wired.
- Domain types are `Codable` and `Sendable`. Swift 6 strict concurrency stays on.

## Git flow

- `main` is the only long-lived branch.
- Start every change on a new branch from an up-to-date `main`. One chunk per branch, named with the chunk ID and a short kebab-case description (`c03-cadence-and-neglect`). Work outside a chunk takes a plain kebab-case name.
- Never commit or push directly to `main`. Every change reaches it through a PR.
- One chunk is one PR. The PR closes the chunk's issue (`Closes #3`).
- Do not start a chunk before the chunks it depends on are merged.
- Merge with rebase (`gh pr merge --rebase`). No merge commits, and no merging one branch back into another.
- To catch up with `main`, rebase onto it. Force-push only your own feature branch, with `--force-with-lease`.
- Delete the branch once its PR is merged.

## Commits and PRs

- Small commits when they make sense, one logical change each. The subject says what changed, in the imperative.
- Commit only source and `Tony.xcodeproj`: never `build/`, `.build/`, `DerivedData/`, `xcuserdata/`, or local files like `.DS_Store`.
- PR description: what changed and why, how it was tested (commands, simulators and devices), screenshots for visual changes, open questions for Matteo.
- Copy the chunk's "Done when" into the PR and say how each part was shown to hold.
- Keep PRs reviewable. Split unrelated changes into separate PRs.

## Before every push

All of these pass, every time. Never push red.

1. `make test`: the import check and every `TonyCore`, `TonyStore` and `TonyPresentation` test pass.
2. `make build`: the app and the widget extension build with no errors and no warnings.
3. `make run` and `make test-ui` when the change touches the app: it launches in the simulator and the changed screen behaves as described.
4. Look at it when the change is visual: English and French, iPhone and iPad, the largest Dynamic Type size. The app is dark only.
5. Read your own diff: no secrets, no debug code, no leftover files, no unrelated changes.

During development, run the smallest relevant test first (`xcodebuild test -project Tony.xcodeproj -scheme TonyUnitTests -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:TonyCoreTests/<suite>`). Before pushing, run all the gates above.

- Never claim a test passed unless it was actually executed.
- If a test cannot be executed, report it and explain why.
- When a test fails, fix the code or, if the behaviour changed on purpose, the test. Never skip, loosen or delete a test to get green.
- A known gap is marked with `withKnownIssue` and its reason.
- Claude cannot run on a real iPhone. A chunk labelled `needs device` is not done until Matteo has run it on one: say exactly what to check on the device, and never report that part as verified.

## Development practices

- Fix the cause, not the symptom. Keep the change to what was asked; flag other problems instead of fixing them on the side.
- Names in full words (`completion`, `busyInterval`, `weeklyQuota`). Only `x`, `y` and `_` may be short. Follow the Swift API Design Guidelines.
- Very few comments: only for something genuinely surprising. Explain the change in the PR instead.
- Fix warnings like errors: the compiler and the build end with none. Never silence one with `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency` without a one-line reason.
- No force unwraps, `try!` or `fatalError` in shipping code paths. Tests may use `#require`.
- Tests use Swift Testing (`import Testing`). Planner behaviour is tested with fixtures and table-driven cases, not through the UI. Only the UI tests in `TonyAppUITests` use XCTest, because Swift Testing cannot drive an app.
- New behaviour comes with a test, or an updated one.
- No hardcoded user-facing text: every string goes through the String Catalog, in English and French. Templates and prompts are localised too.
- No hardcoded colours, fonts, sizes or radii in views: use the design tokens and components of `TonyUIKit`, taken from the Figma file.
- Shell scripts and Makefile targets read step by step: named variables, one action per line. No dense one-liners.
- Prefer Apple frameworks over third-party code.
- ALWAYS evaluate existing solid libraries before developing in house when Apple frameworks do not cover the need. Bring Matteo the candidates with their reliability, ease of use, adoption, maintenance and licence, and a recommendation; he picks.
- No new dependency (Swift package or build tool), external service or network request without Matteo's approval. Pin exact versions.
- No new entitlement, capability, permission prompt or background mode without Matteo's approval. Every permission has a usage description in both languages.
- Secrets, signing certificates and provisioning profiles never go in the repo or in logs.
- Keep the docs true: when a rule or decision changes, update CLAUDE.md in the same PR.

## Simplicity

- Prefer the simplest implementation that satisfies the chunk.
- Do not introduce abstractions, helpers, configuration or extensibility without a demonstrated need. The protocols listed under Architecture rules are the agreed seams; do not add others on speculation.
- Do not build ahead: a chunk delivers what its issue says, not what a later chunk will need.
- Reuse existing patterns before introducing alternatives.
- Avoid duplicating existing functionality.
- Avoid refactoring unrelated code.
- Do not optimize prematurely. Address measurable performance problems or explicit requirements.

## Privacy

- Server-side services are fine, such as the task catalogue (D14). Each new one still needs Matteo's approval, like any external service.
- The app never sends user data to a server: nothing that identifies the person or the device, and none of their task list, completions, calendar, health, routine, preferences or location. Nothing is logged or put in analytics.
- A request carries only the generic, anonymous input the service needs. The task catalogue receives the name of a task being created and the language, nothing else. Until it exists, `TableTaskCatalog` answers from `TonyApp/Catalog/TaskCatalog.json` and nothing leaves the device.
- Ask for each permission when the feature that needs it is first used, and keep the app working when it is refused.
- Read only what the feature needs (busy intervals, not event titles; sleep and workouts, not other health data).
- Fixtures and tests use invented data, never Matteo's real calendar or health records.

## Accessibility and compatibility

- Every interactive element has a VoiceOver label and is reachable with VoiceOver and Full Keyboard Access.
- Text uses the type styles and scales with Dynamic Type. Layouts hold at the largest accessibility size.
- Touch targets are at least 44 by 44 points.
- Respect Reduce Motion for non-essential motion, and do not carry meaning by colour alone.
- The app is dark only: Figma defines one palette, and the app forces the dark appearance. Check iPhone and iPad in both orientations where the screen supports them.
- The deployment target is iOS 27. Do not add availability checks or fallbacks for older versions.

## Localisation

- English and French ship together. A string missing in one language is a bug, not a fallback.
- Dates, times, numbers and weekdays are formatted with the locale that is passed in, never by hand.
- Parsing and model prompts are checked in both languages.
- Flag text that looks misleading or inconsistent rather than inventing corrections.

## Execution

- Before changing code, read the chunk's issue, the chunks it depends on, and the code and conventions around the change.
- Make changes directly when requirements are clear and within scope.
- Do not stop to ask questions about decisions already covered by these instructions or established project conventions.
- Ask Matteo when requirements are ambiguous, architectural approval is needed, or a decision has legal, financial or external consequences (App Store, TestFlight, signing, paid services).
- Do not silently expand the scope of a task.
- At completion, report:
  - What changed.
  - Tests and checks actually executed.
  - Any tests that could not be executed and why, including anything left to check on a device.
  - Outstanding concerns or decisions requiring Matteo's input.
