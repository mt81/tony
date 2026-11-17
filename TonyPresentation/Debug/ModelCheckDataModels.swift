import Foundation
import MemberwiseInit
import TonyUIModels

/// A debug screen that runs the on-device model on the evaluation set and shows what came back.
@MemberwiseInit(.public)
public struct ModelCheckScreenDataModel {
    @MemberwiseInit(.public)
    public struct Row: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String
        public var input: String
        /// Nil until the case has run.
        public var output: String?
        public var verdict: String
        /// Nil until the case has run.
        public var hasPassed: Bool?
    }

    public var title: String
    public var availability: String
    public var run: ButtonDataModel
    /// The pass rates, once every case has run.
    public var report: String?
    public var shareReport: String
    public var rows: [Row]
    /// What the widget and the background task noted when they last tried the model.
    public var extensionChecks: [String]
    public var requestBackgroundCheck: ButtonDataModel
    public var backgroundCheckRequest: String?
    public var onAppear: @MainActor () -> Void
}
