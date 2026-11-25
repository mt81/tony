import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

@MainActor
private func viewModel(_ store: PermissionStore, language: String = "en") throws -> PermissionViewModel {
    PermissionViewModel(store: store, context: try Sample.context(language: language))
}

@MainActor
@Test func continueShowsTheSystemPromptAndReturnsItsAnswerOnceTheSheetCloses() async throws {
    let calendar = FakePermissionProvider(status: .notDetermined, answer: .granted)
    let store = PermissionStore.fake(calendar)

    let asking = Task { await store.request(.calendar) }
    await store.untilAsking()
    let sheet = try viewModel(store)
    let shown = (sheet.isPresented, sheet.title, sheet.grant.title, sheet.close.title, sheet.illustration)
    let promptsBeforeTapping = await calendar.requestCount
    sheet.grant.action.execute()
    let answer = await asking.value

    #expect(shown == (true, "Plan around your events", "Continue", "Close", .tony))
    #expect(sheet.explanation.hasPrefix("Tony reads when you’re busy, never what your events are about"))
    #expect(promptsBeforeTapping == 0)
    #expect(answer == .granted)
    #expect(await calendar.requestCount == 1)
    #expect(try viewModel(store).isPresented == false)
}

@MainActor
@Test func closingTheSheetAsksNothing() async throws {
    let calendar = FakePermissionProvider(status: .notDetermined)
    let store = PermissionStore.fake(calendar)

    let asking = Task { await store.request(.calendar) }
    await store.untilAsking()
    try viewModel(store).dismiss.execute()

    #expect(await asking.value == .notDetermined)
    #expect(await calendar.requestCount == 0)
    #expect(try viewModel(store).isPresented == false)
}

@MainActor
@Test func aGrantedPermissionReturnsAtOnceWithoutTheSheet() async throws {
    let calendar = FakePermissionProvider(status: .granted)
    let store = PermissionStore.fake(calendar)

    #expect(await store.request(.calendar) == .granted)
    #expect(store.state.isAsking == false)
    #expect(await calendar.requestCount == 0)
}

@MainActor
@Test func aRefusedPermissionOpensSettingsInsteadOfThePrompt() async throws {
    let calendar = FakePermissionProvider(status: .denied)
    var settingsOpened = 0
    let store = PermissionStore(providers: [calendar]) { settingsOpened += 1 }

    let asking = Task { await store.request(.calendar) }
    await store.untilAsking()
    let sheet = try viewModel(store)
    let french = try viewModel(store, language: "fr")
    let titles = (sheet.grant.title, french.grant.title)
    let explanation = sheet.explanation
    await store.grant()

    #expect(titles == ("Open Settings", "Ouvrir Réglages"))
    #expect(explanation == "Calendar access is off. Turn it on in Settings and Tony will plan around your events.")
    #expect(await asking.value == .denied)
    #expect(settingsOpened == 1)
    #expect(await calendar.requestCount == 0)
}

@MainActor
@Test func theSheetIsWordedInFrench() async throws {
    let store = PermissionStore.fake(FakePermissionProvider(status: .notDetermined))

    let asking = Task { await store.request(.calendar) }
    await store.untilAsking()
    let sheet = try viewModel(store, language: "fr")
    let words = (sheet.title, sheet.grant.title, sheet.close.title)
    store.notNow()
    _ = await asking.value

    #expect(words == ("Planifier autour de tes événements", "Continuer", "Fermer"))
}
