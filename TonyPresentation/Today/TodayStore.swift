import Foundation
import TonyCore

/// Holds the Today tab's state and is the only thing that changes it.
@MainActor
public final class TodayStore {
    let state = TodayState()

    private let coordinator: PlanCoordinator
    private let permissions: PermissionStore
    private let briefingWriter: BriefingWriter
    private let repository: any Repository
    private let catalog: (any TaskCatalog)?
    /// Reads the sentence a new task is typed in, with the rules; nil when there is no model.
    private let languageService: (any LanguageService)?
    private let calendar: Calendar
    /// The language of the briefing and of the catalogue's answers.
    private let locale: Locale
    /// How long typing must pause before the catalogue is asked.
    private let suggestionDelay: Duration

    /// The task form's latest lookup. A new one cancels it.
    private(set) var editorWork: Task<Void, Never>?
    /// The plan the model is wording, so that it is asked once per plan.
    private var wordingPlan: DayPlan?

    public init(
        coordinator: PlanCoordinator,
        permissions: PermissionStore,
        briefingWriter: BriefingWriter,
        repository: any Repository,
        catalog: (any TaskCatalog)?,
        languageService: (any LanguageService)? = nil,
        calendar: Calendar,
        locale: Locale,
        suggestionDelay: Duration = .milliseconds(400)
    ) {
        self.coordinator = coordinator
        self.permissions = permissions
        self.briefingWriter = briefingWriter
        self.repository = repository
        self.catalog = catalog
        self.languageService = languageService
        self.calendar = calendar
        self.locale = locale
        self.suggestionDelay = suggestionDelay
    }

    /// Plans the day, and reads the name and calendar access. Called when Today appears and when the app comes back.
    public func load() async {
        await coordinator.start()
        let name = ((try? await repository.preferences()) ?? []).first { $0.key == Preference.userNameKey }?.value ?? ""
        state.userName = name.isEmpty ? nil : name
        state.calendarAccess = await permissions.status(of: .calendar)
        await show(await coordinator.current)
    }

    /// Shows each new plan for as long as the caller waits.
    public func followPlans() async {
        for await planned in await coordinator.plans() {
            await show(planned)
        }
    }

    func check(_ item: DayPlan.Item) async {
        await record(.done, on: item)
    }

    func postpone(_ item: DayPlan.Item) async {
        await record(.later, on: item)
    }

    func refuse(_ item: DayPlan.Item) async {
        await record(.notToday, on: item)
    }

    func planAroundEvents() async {
        let access = await permissions.request(.calendar)
        state.calendarAccess = access
        if access == .granted {
            await coordinator.refresh()
            await show(await coordinator.current)
        }
    }

    /// Opens the task form on the composer.
    public func startAdding(id: UUID, stepID: UUID, now: Date) {
        state.editor = .newTask(id: id, stepID: stepID, now: now)
    }

    func edit(_ action: TaskEditor.Action) {
        guard var editor = state.editor else { return }
        let effects = TaskEditor.reduce(&editor, action)
        state.editor = editor
        for effect in effects {
            editorWork?.cancel()
            editorWork = Task { [weak self] in
                await self?.run(effect)
            }
        }
    }

    func cancelEditing() {
        editorWork?.cancel()
        state.editor = nil
    }

    func saveEditor() async {
        guard let editor = state.editor, editor.isValid else { return }
        editorWork?.cancel()
        state.editor = nil
        do {
            try await repository.save(editor.editedTask)
        } catch {
            state.failure = .task
            return
        }
        await coordinator.refresh()
        await show(await coordinator.current)
    }

    func dismissAlert() {
        state.failure = nil
    }

    private func record(_ action: PlanAction, on item: DayPlan.Item) async {
        do {
            try await coordinator.record(action, on: item)
        } catch {
            state.failure = .answer
            return
        }
        await show(await coordinator.current)
    }

    /// Shows the plan, and has the model word it when it is new. Keeps the plan on screen when there is none.
    func show(_ planned: PlannedDay?) async {
        guard let planned else { return }
        state.planned = planned
        guard state.briefing?.plan != planned.plan, wordingPlan != planned.plan else { return }
        wordingPlan = planned.plan
        let context = PresentationContext(now: planned.plannedAt, calendar: calendar, locale: locale)
        let request = TodayWording(planned: planned, userName: nil, context: context).briefingRequest
        let text = await briefingWriter.briefing(for: request)
        if wordingPlan == planned.plan {
            wordingPlan = nil
        }
        if let text {
            state.briefing = TodayState.WordedBriefing(plan: planned.plan, text: text)
        }
    }

    private func run(_ effect: TaskEditor.Effect) async {
        let action: TaskEditor.Action? =
            switch effect {
            case .suggestSteps(let name):
                await TaskEditor.suggestSteps(forName: name, catalog: catalog, locale: locale, after: suggestionDelay)
            case .read(let sentence, let now):
                await TaskEditor.read(sentence: sentence, now: now, calendar: calendar, locale: locale, service: languageService)
            }
        guard !Task.isCancelled, let action else { return }
        edit(action)
    }
}
