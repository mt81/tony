import Foundation
import Testing
@testable import TonyPresentation

@Test(arguments: [
    (source: IndexSet([0]), destination: 3, expected: ["B", "C", "A", "D"]),
    (source: IndexSet([3]), destination: 0, expected: ["D", "A", "B", "C"]),
    (source: IndexSet([1]), destination: 4, expected: ["A", "C", "D", "B"]),
    (source: IndexSet([0, 2]), destination: 4, expected: ["B", "D", "A", "C"]),
    (source: IndexSet([1, 3]), destination: 0, expected: ["B", "D", "A", "C"]),
    (source: IndexSet([2]), destination: 2, expected: ["A", "B", "C", "D"]),
    (source: IndexSet([9]), destination: 0, expected: ["A", "B", "C", "D"]),
])
func moveBehavesLikeAListMove(source: IndexSet, destination: Int, expected: [String]) {
    var letters = ["A", "B", "C", "D"]

    letters.move(fromOffsets: source, toOffset: destination)

    #expect(letters == expected)
}

@Test func removeAtOffsetsDropsThoseElements() {
    var letters = ["A", "B", "C", "D"]

    letters.remove(atOffsets: [0, 2, 9])

    #expect(letters == ["B", "D"])
}
