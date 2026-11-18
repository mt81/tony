import Foundation

/// Something a control runs when the user acts on it, with what the user gave: the new text, the new state of a toggle.
/// Two of them are equal when they would do the same thing.
public protocol Executable<Argument>: Equatable {
    associatedtype Argument
    @MainActor func execute(_ argument: Argument)
}

extension Executable where Argument == Void {
    @MainActor
    public func execute() {
        execute(())
    }
}

extension Executable {
    /// Compares with an executable of any type: equal only when both are of the same type and equal.
    public func isEqual(to other: any Executable) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

/// The parameters of an action whose closure needs none.
public struct NoParameters: Equatable, Sendable {}

/// Runs its closure with its parameters and the argument the control passes. Equality compares the identifier and the
/// parameters only, so the parameters must hold everything the closure depends on: it reads anything else when it runs.
public struct Action<Parameters: Equatable, Argument>: Executable {
    public let id: String
    private let parameters: Parameters
    private let executionClosure: @MainActor (_ parameters: Parameters, _ argument: Argument) -> ()

    public init(
        id: String,
        parameters: Parameters,
        executionClosure: @escaping @MainActor (_ parameters: Parameters, _ argument: Argument) -> ()
    ) {
        self.id = id
        self.parameters = parameters
        self.executionClosure = executionClosure
    }

    @MainActor
    public func execute(_ argument: Argument) {
        executionClosure(parameters, argument)
    }

    public static func == (lhs: borrowing Action<Parameters, Argument>, rhs: borrowing Action<Parameters, Argument>) -> Bool {
        guard lhs.id == rhs.id else { return false }
        return lhs.parameters == rhs.parameters
    }
}

extension Action where Parameters == NoParameters {
    public init(id: String, executionClosure: @escaping @MainActor (_ argument: Argument) -> ()) {
        self.init(id: id, parameters: NoParameters()) { _, argument in executionClosure(argument) }
    }
}
