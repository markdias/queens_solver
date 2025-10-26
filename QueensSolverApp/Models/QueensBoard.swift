import Foundation

public struct QueensBoard: Equatable, Hashable {
    public let size: Int
    public let regions: [[Int]]
    public let crowns: Set<Position>

    public init(size: Int, regions: [[Int]], crowns: Set<Position> = []) {
        precondition(regions.count == size && regions.allSatisfy { $0.count == size }, "Regions must match board size")
        self.size = size
        self.regions = regions
        self.crowns = crowns
    }

    public func region(for position: Position) -> Int {
        regions[position.row][position.column]
    }

    public func placingCrown(at position: Position) -> QueensBoard {
        var newCrowns = crowns
        newCrowns.insert(position)
        return QueensBoard(size: size, regions: regions, crowns: newCrowns)
    }
}

public struct Position: Hashable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}
