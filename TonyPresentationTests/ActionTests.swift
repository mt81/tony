import Testing
import TonyUIModels

@MainActor
@Test func anActionRunsItsClosureWithItsParametersAndTheArgument() {
    var received: [String] = []
    let rename: any Executable<String> = Action(id: "rename", parameters: 3) { step, name in received.append("\(step) \(name)") }
    let save: any Executable<Void> = Action(id: "save") { _ in received.append("save") }

    rename.execute("Wash")
    save.execute()

    #expect(received == ["3 Wash", "save"])
}

@Test func actionsAreEqualWhenTheirIdentifiersAndParametersAre() {
    let first = Action<Int, Void>(id: "open", parameters: 1) { _, _ in }

    #expect(first == Action<Int, Void>(id: "open", parameters: 1) { _, _ in })
    #expect(first != Action<Int, Void>(id: "open", parameters: 2) { _, _ in })
    #expect(first != Action<Int, Void>(id: "delete", parameters: 1) { _, _ in })
    #expect(!first.isEqual(to: Action<String, Void>(id: "open", parameters: "1") { _, _ in }))
}

@Test func controlsCompareTheirActions() {
    let save = ButtonDataModel(title: "Save", action: Action(id: "save") { _ in })
    let name = TextFieldDataModel(title: "Name", text: "", onChange: Action(id: "rename") { _ in })

    #expect(save == ButtonDataModel(title: "Save", action: Action(id: "save") { _ in }))
    #expect(save != ButtonDataModel(title: "Save", action: Action(id: "cancel") { _ in }))
    #expect(name == TextFieldDataModel(title: "Name", text: "", onChange: Action(id: "rename") { _ in }))
    #expect(name != TextFieldDataModel(title: "Name", text: "", onChange: Action(id: "rename") { _ in }, onSubmit: Action(id: "save") { _ in }))
}
