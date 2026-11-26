# Tony

iOS 27 app (iPhone, iPad; English, French) that plans the day around recurring tasks, goals and the calendar. Part of the AHDH Claude project.

- Project: https://claude.ai/cowork/project/01a1cafa-136f-77e7-947e-4dbd55343a28
- Docs (Notion): https://app.notion.com/p/Tony-42281c5914d280518492fb08cb48c089
- Figma (colours, type, components, wireframes): https://www.figma.com/design/VKMc5C6tBa8W1gemsrrZAc

## Writing

- Replies to Matteo and PR descriptions: short, to the point. No reasoning or background unless asked.
- PR description: what changed (bullets), tests run, device checks left, questions. Copy the chunk's "Done when" with one line of proof each. Screenshots for visual changes.
- Report at completion: what changed, tests run, tests not run and why (device checks included), decisions for Matteo.

## Targets

| Target | Contains | Verified by |
| --- | --- | --- |
| `TonyCore` | Domain model, cadence, context, planner, consistency, protocols | `TonyCoreTests` |
| `TonyStore` | SwiftData models, `Repository` implementation (app and extension) | `TonyStoreTests`, in memory |
| `TonyUIModels` | Data models of controls and components, plain Swift | `TonyUIKit` previews |
| `TonyUIKit` | SwiftUI controls and components, tokens (colour, type, spacing, radius), fonts, artwork | Previews, Debug component gallery |
| `TonyPresentation` | Per screen: state, store, view model, part data models; presentation strings | `TonyPresentationTests` |
| `TonyScreens` | SwiftUI screens drawing `TonyPresentation` models with `TonyUIKit` | Previews |
| `TonyApp` | Wiring, tab bar, system adapters (EventKit), MET Norway weather | `TonyAppUITests`, then device |
| `TonyWidgets` | Widget timeline provider, App Intents | Device |

- One Xcode project, `Tony.xcodeproj`, edited in Xcode, no generator. Folders `<Target>/` and `<Target>Tests/` are synchronized: a file added to a folder joins its target.
- One package: MemberwiseInit 0.6.0 (exact). Structs whose init only assigns use `@MemberwiseInit(.public)` (`TonyCore`, `TonyUIModels`, `TonyPresentation`).
- A test target links every framework its tests import.
- Frameworks load resources with `#bundle`, never `Bundle.main`.
- App and extension `Info.plist` and `.entitlements` are in `Configuration/`.
- Shared schemes: `TonyApp` (app, UI tests), `TonyUnitTests`, `TonyUIKit` (previews).
- App group: `group.com.mt81.tony`.
- Debug builds only: a Debug tab (model check, calendar check, component gallery; English, not translated), and the launch argument `-now 08:00` to freeze the clock today.
- Background task identifier `com.mt81.tony.refresh`, used only by the debug model check until C21.
- `TonyDebug/`: debug-only source compiled into app and extension.

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

- Matteo owns architecture. Follow the existing architecture, targets, technologies and conventions.
- His approval is needed to add, replace or restructure patterns, technologies, dependencies, integrations or targets, and to change decisions D1 to D14 (solution document).
- For those, bring problem, options, tradeoffs, recommendation; wait.
- Local implementation choices within the patterns are yours; don't ask about them.
- Flag architectural risks outside the task; don't fix them unasked.
- Ask Matteo when requirements are ambiguous, or for legal, financial or external consequences (App Store, TestFlight, signing, paid services).
- New UI (screen, sheet, component, new state or section) follows the [UX guidelines](https://app.notion.com/p/42381c5914d281c8a36bccefb5b83e1b) (then Apple's HIG), and is drawn first as a Figma wireframe beside the existing frames and approved by Matteo. Build only what he approved.
- Figma costs credits: read single nodes, one screenshot after composing and one after a fix, few `use_figma` calls, copy existing frames and components. No Figma AI generation without asking.

## Architecture

- Logic lives in `TonyCore`, which never imports UIKit, SwiftUI, EventKit, HealthKit, WeatherKit, WidgetKit, SwiftData or UserNotifications.
- System frameworks sit behind `TonyCore` protocols: `CalendarSource`, `HealthSource`, `WeatherSource`, `LanguageService`, `NudgeScheduler`, `PermissionProvider`, `Repository`, `TaskCatalog`. Adapters in the app, fakes in tests. No other seams on speculation.
- The planner is deterministic: time, calendar and locale are passed in, never `Date()`, `Calendar.current` or `Locale.current` in `TonyCore`.
- The on-device model only words and parses, never decides the plan. Its output is validated, and every model feature has a rule-based fallback.
- Views (`TonyUIKit`, `TonyUIModels`, `TonyScreens`) never see business types; they see data models.
- `TonyPresentation` is the only target that knows both. It imports `TonyUIModels`, never SwiftUI or views.
- `TonyScreens` imports `TonyPresentation` and `TonyUIKit`, never `TonyCore`.
- `TonyApp` wires stores to adapters. `make check-imports` enforces these boundaries.
- Domain types are `Codable` and `Sendable`. Swift 6 strict concurrency on.

## Screens

One store per screen, unidirectional (see the You tab: `YouState`, `YouStore`, `YouViewModel`):

1. State: internal `@Observable` class of business values, seen only by `TonyPresentation`.
2. Store: the only writer of the state; one method per change; does the async work; dependencies (clock included) passed to `init`.
3. View model: struct over store and presentation context. Each property calls a pure static reducer on the whole state (`name(state, context:)`) that returns what the view shows.
4. View: takes the view model; each part is a small view reading only its own properties.
5. User action → data model closure → store method.

- A form with its own lifetime may get a child store, created by its screen's store.
- Today, Tasks and Debug still use the older `Store<Feature>` until converted.
- View models have a `preview(...)` factory under `#if DEBUG`, on `TonyPresentation/Store/PreviewSources.swift`.
- Components take their own data model: values already localised and formatted, plus actions. Actions are `Action(id:parameters:) { parameters, argument in … }` (`TonyUIModels/Action.swift`); equality is identifier and parameters, so parameters hold everything the closure depends on. Awaited lifecycle work (`load()`) stays an async view model method.
- Views decide nothing: no `if` on domain state, no formatting, no own strings.
- Component data models in `TonyUIModels`, their views in `TonyUIKit`. Screen view models in `TonyPresentation`, screens in `TonyScreens`.
- Every view and token has a preview with sample data, inside `#if DEBUG`, not translated.
- Stores and view models are tested in `TonyPresentationTests` with fakes. UI tests only check wiring.

## Git

- `main` is the only long-lived branch. Never commit or push to it; everything goes through a PR.
- Branch from an up-to-date `main`: `c03-cadence-and-neglect` for a chunk, plain kebab-case otherwise.
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
- Fix causes, not symptoms. Stay in scope; flag other problems.
- Simplest thing that satisfies the chunk. No abstractions, helpers, configuration or building ahead without a need. Reuse patterns, don't duplicate, don't refactor unrelated code, don't optimise without a measured problem.
- Full-word names (`completion`, `busyInterval`); only `x`, `y`, `_` short. Swift API Design Guidelines.
- Comments only for the surprising.
- No warnings. `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency` only with a one-line reason.
- No force unwraps, `try!` or `fatalError` in shipping code. Tests may `#require`.
- Swift Testing everywhere except the XCTest UI tests. Planner behaviour: fixtures and table-driven tests. New behaviour comes with a test.
- No hardcoded user-facing text: String Catalog, English and French, templates included.
- Model prompts: one English `.txt` per prompt in `TonyPresentation/Prompts`, answering in `{language}` from the passed locale.
- No hardcoded colours, fonts, sizes or radii: `TonyUIKit` tokens and components, from Figma.
- Shell scripts and Makefile: named variables, one action per line.
- Prefer Apple frameworks. Otherwise bring Matteo library candidates (reliability, ease, adoption, maintenance, licence, recommendation); he picks.
- Matteo approves every new dependency, external service, network request, entitlement, capability, permission prompt or background mode. Pin exact versions. Usage descriptions in both languages.
- No secrets, certificates or profiles in the repo or logs.
- When a rule or decision changes, update this file in the same PR.

## Privacy

- Server-side services (like the task catalogue, D14) need Matteo's approval.
- No user data leaves the device: nothing identifying the person or device, no tasks, completions, calendar, health, routine, preferences or location. No logging or analytics.
- Requests carry only generic, anonymous input. The catalogue gets the new task's name and the language. Until it exists, `TableTaskCatalog` reads `TonyApp/Catalog/TaskCatalog.json`.
- MET Norway (api.met.no) gets the saved place's coordinates rounded to about 10 km, only when some task needs some weather. The User-Agent names the app and the repo, as MET requires.
- Ask a permission only after the user taps a call to action that needs it, through the permission manager (`PermissionStore`) and its sheet: one button, **Continue**, and a close ✕. Never at launch. The app works if refused.
- Read only what's needed (busy intervals, not titles; sleep and workouts, not other health data).
- Fixtures use invented data, never Matteo's real records.

## Accessibility, compatibility, localisation

- VoiceOver labels on every interactive element, reachable with VoiceOver and Full Keyboard Access.
- Type styles with Dynamic Type; layouts hold at the largest size. Touch targets at least 44 × 44.
- Respect Reduce Motion; never carry meaning by colour alone.
- Light only. Check iPhone and iPad in supported orientations.
- iOS 27 only: no availability checks.
- English and French ship together; a missing string is a bug.
- Dates, times, numbers, weekdays formatted with the passed locale.
- Parsing and prompts checked in both languages.
- Flag misleading text instead of inventing fixes.
