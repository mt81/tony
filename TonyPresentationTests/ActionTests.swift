import Testing
import TonyUIModels

@MainActor
@Test func anActionRunsItsClosureWithItsParameters() {
    var received: [String] = []
    let action = Action("add_task") { received.append($0) }

    action.execute()

    #expect(received == ["add_task"])
}

@Test func actionsAreEqualWhenTheirParametersAre() {
    let first = Action("add_task") { _ in }
    let second = Action("add_task") { _ in }
    let other = Action("open_task") { _ in }

    #expect(first == second)
    #expect(first != other)
    #expect(first.isEqual(to: second))
    #expect(!first.isEqual(to: Action(1) { _ in }))
}

@Test func buttonsCompareTheirActions() {
    let save = ButtonDataModel(title: "Save", action: Action("save") { _ in })

    #expect(save == ButtonDataModel(title: "Save", action: Action("save") { _ in }))
    #expect(save != ButtonDataModel(title: "Save", action: Action("cancel") { _ in }))
}
