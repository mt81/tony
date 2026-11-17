import Foundation
import TonyCore
import TonyUIModels

/// The Today tab: the day's plan from the coordinator, and the user's answers to it.
public enum TodayFeature: Feature {
    /// The model's wording of one plan. It is shown for as long as that plan is the one on screen.
    public struct WordedBriefing: Sendable, Equatable {
        public var plan: DayPlan
        public var text: String
    }

    public struct State: Sendable, Equatable {
        public var planned: PlannedDay?
        public var briefing: WordedBriefing?
        /// The name entered in the You tab; nil when there is none.
        public var userName: String?
        public var editor: TaskEditor.State?
        public var failure: Failure?

        public init() {}
    }

    public enum Failure: Sendable, Equatable {
        case answer
        case task
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case nameLoaded(String?)
        /// The coordinator's latest plan; nil while there is none.
        case planned(PlannedDay?)
        /// The model's wording of that plan; nil when it gave none and the template stays.
        case briefingWorded(plan: DayPlan, text: String?)
        case checkTapped(DayPlan.Item)
        case laterTapped(DayPlan.Item)
        case notTodayTapped(DayPlan.Item)
        case addTapped(id: UUID, stepID: UUID, now: Date)
        case editor(TaskEditor.Action)
        case editorCancelled
        case editorSaved
        case failed(Failure)
        case alertDismissed
    }

    public enum Effect: Sendable, Equatable {
        case plan
        case loadName
        case wordBriefing(PlannedDay)
        case record(PlanAction, on: DayPlan.Item)
        case save(TonyTask)
        case editor(TaskEditor.Effect)
    }

    public struct Environment: Sendable {
        public var coordinator: PlanCoordinator
        public var briefingWriter: BriefingWriter
        public var repository: any Repository
        public var catalog: (any TaskCatalog)?
        public var calendar: Calendar
        /// The language of the briefing and of the catalogue's answers.
        public var locale: Locale
        /// How long typing must pause before the catalogue is asked.
        public var suggestionDelay: Duration

        public init(
            coordinator: PlanCoordinator,
            briefingWriter: BriefingWriter,
            repository: any Repository,
            catalog: (any TaskCatalog)?,
            calendar: Calendar,
            locale: Locale,
            suggestionDelay: Duration = .milliseconds(400)
        ) {
            self.coordinator = coordinator
            self.briefingWriter = briefingWriter
            self.repository = repository
            self.catalog = catalog
            self.calendar = calendar
            self.locale = locale
            self.suggestionDelay = suggestionDelay
        }
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared:
            return [.plan, .loadName]
        case .nameLoaded(let name):
            state.userName = name
        case .planned(let planned):
            guard let planned else { break }
            state.planned = planned
            if state.briefing?.plan != planned.plan {
                return [.wordBriefing(planned)]
            }
        case .briefingWorded(let plan, let text):
            state.briefing = text.map { WordedBriefing(plan: plan, text: $0) } ?? state.briefing
        case .checkTapped(let item):
            return [.record(.done, on: item)]
        case .laterTapped(let item):
            return [.record(.later, on: item)]
        case .notTodayTapped(let item):
            return [.record(.notToday, on: item)]
        case .addTapped(let id, let stepID, let now):
            state.editor = .newTask(id: id, stepID: stepID, now: now)
        case .editor(let editorAction):
            guard var editor = state.editor else { break }
            let effects = TaskEditor.reduce(&editor, editorAction)
            state.editor = editor
            return effects.map(Effect.editor)
        case .editorCancelled:
            state.editor = nil
        case .editorSaved:
            guard let editor = state.editor, editor.isValid else { break }
            state.editor = nil
            return [.save(editor.editedTask)]
        case .failed(let failure):
            state.failure = failure
        case .alertDismissed:
            state.failure = nil
        }
        return []
    }

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        let coordinator = environment.coordinator
        switch effect {
        case .plan:
            await coordinator.start()
        case .loadName:
            let preferences = (try? await environment.repository.preferences()) ?? []
            let name = preferences.first { $0.key == Preference.userNameKey }?.value ?? ""
            return .nameLoaded(name.isEmpty ? nil : name)
        case .wordBriefing(let planned):
            var state = State()
            state.planned = planned
            let context = PresentationContext(now: planned.plannedAt, calendar: environment.calendar, locale: environment.locale)
            let request = TodayWording(state: state, context: context).briefingRequest
            return .briefingWorded(plan: planned.plan, text: await environment.briefingWriter.briefing(for: request))
        case .record(let action, let item):
            do {
                try await coordinator.record(action, on: item)
            } catch {
                return .failed(.answer)
            }
        case .save(let task):
            do {
                try await environment.repository.save(task)
            } catch {
                return .failed(.task)
            }
            await coordinator.refresh()
        case .editor(.suggestSteps(let name)):
            let action = await TaskEditor.suggestSteps(
                forName: name,
                catalog: environment.catalog,
                locale: environment.locale,
                after: environment.suggestionDelay
            )
            return action.map { .editor($0) }
        }
        return .planned(await coordinator.current)
    }

    public static func cancellationKey(for effect: Effect) -> String? {
        switch effect {
        case .editor: "editor"
        case .wordBriefing: "wordBriefing"
        default: nil
        }
    }
}
