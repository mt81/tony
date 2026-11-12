import Testing
@testable import TonyCore

@Test func appGroupIdentifierIsAnAppGroup() {
    #expect(TonyCore.appGroupIdentifier.hasPrefix("group."))
}
