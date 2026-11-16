import Foundation

/// A debug screen that runs the on-device model on the evaluation set and shows what came back.
public struct ModelCheckScreenDataModel {
    public struct Row: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String
        public var input: String
        /// Nil until the case has run.
        public var output: String?
        public var verdict: String
        /// Nil until the case has run.
        public var hasPassed: Bool?

        public init(id: String, title: String, input: String, output: String?, verdict: String, hasPassed: Bool?) {
            self.id = id
            self.title = title
            self.input = input
            self.output = output
            self.verdict = verdict
            self.hasPassed = hasPassed
        }
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

    public init(
        title: String,
        availability: String,
        run: ButtonDataModel,
        report: String?,
        shareReport: String,
        rows: [Row],
        extensionChecks: [String],
        requestBackgroundCheck: ButtonDataModel,
        backgroundCheckRequest: String?,
        onAppear: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.availability = availability
        self.run = run
        self.report = report
        self.shareReport = shareReport
        self.rows = rows
        self.extensionChecks = extensionChecks
        self.requestBackgroundCheck = requestBackgroundCheck
        self.backgroundCheckRequest = backgroundCheckRequest
        self.onAppear = onAppear
    }
}
