import Foundation

/// Something a control runs when the user acts on it. Two of them are equal when they would do the same thing.
public protocol Executable: Equatable {
    @MainActor func execute()
}

extension Executable {
    /// Compares with an executable of any type: equal only when both are of the same type and equal.
    public func isEqual(to other: any Executable) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

/// Runs its closure with its parameters. Equality compares the parameters only, so they must hold everything
/// the closure depends on: the closure reads anything else at the moment it runs.
public struct Action<Parameters: Equatable>: Executable {
    private let parameters: Parameters
    private let executionClosure: @MainActor (_ parameters: Parameters) -> ()

    public init(_ parameters: Parameters, executionClosure: @escaping @MainActor (_ parameters: Parameters) -> ()) {
        self.parameters = parameters
        self.executionClosure = executionClosure
    }

    @MainActor
    public func execute() {
        executionClosure(parameters)
    }

    public static func == (lhs: borrowing Action<Parameters>, rhs: borrowing Action<Parameters>) -> Bool {
        lhs.parameters == rhs.parameters
    }
}
