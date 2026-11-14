import Foundation

// SwiftUI has these too, but reducers do not import SwiftUI.
extension Array {
    /// Moves the elements at `source` so that they sit before the element now at `destination`, as a list's move does.
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid = source.filter { indices.contains($0) }
        let moved = valid.map { self[$0] }
        let insertion = Swift.min(destination, count) - valid.count { $0 < destination }
        for index in valid.reversed() {
            remove(at: index)
        }
        insert(contentsOf: moved, at: insertion)
    }

    mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.reversed() where indices.contains(index) {
            remove(at: index)
        }
    }
}
