import Foundation

public struct QueensSolver {
    public init() {}

    public func solve(board: QueensBoard) throws -> QueensBoard {
        var crowns: [Position] = []
        var occupiedColumns = Set<Int>()
        var occupiedRegions = Set<Int>()

        func isValidPlacement(_ position: Position) -> Bool {
            guard !occupiedColumns.contains(position.column) else { return false }
            let regionID = board.region(for: position)
            guard !occupiedRegions.contains(regionID) else { return false }
            for crown in crowns {
                let dr = abs(crown.row - position.row)
                let dc = abs(crown.column - position.column)
                if dr == dc { return false }
                if dr == 1 && dc == 1 { return false }
            }
            return true
        }

        func backtrack(row: Int) -> QueensBoard? {
            if row == board.size {
                let finalCrowns = Set(crowns)
                return QueensBoard(size: board.size, regions: board.regions, crowns: finalCrowns)
            }

            for column in 0..<board.size {
                let position = Position(row: row, column: column)
                guard isValidPlacement(position) else { continue }

                crowns.append(position)
                occupiedColumns.insert(column)
                occupiedRegions.insert(board.region(for: position))

                if let solved = backtrack(row: row + 1) {
                    return solved
                }

                crowns.removeLast()
                occupiedColumns.remove(column)
                occupiedRegions.remove(board.region(for: position))
            }

            return nil
        }

        guard let solution = backtrack(row: 0) else {
            throw SolverError.unsatisfiable
        }

        return solution
    }

}

public enum SolverError: Error {
    case unsatisfiable
}
