import XCTest
@testable import QueensSolverApp

final class QueensSolverTests: XCTestCase {
    func testSolverFindsValidPlacement() throws {
        let regions = [
            [0, 0, 1, 1],
            [0, 2, 2, 1],
            [3, 2, 4, 4],
            [3, 3, 4, 5]
        ]
        let board = QueensBoard(size: 4, regions: regions)
        let solver = QueensSolver()
        let solution = try solver.solve(board: board)

        XCTAssertEqual(solution.crowns.count, 4)

        var seenRows = Set<Int>()
        var seenColumns = Set<Int>()
        var seenRegions = Set<Int>()

        for crown in solution.crowns {
            XCTAssertTrue(seenRows.insert(crown.row).inserted)
            XCTAssertTrue(seenColumns.insert(crown.column).inserted)
            XCTAssertTrue(seenRegions.insert(board.region(for: crown)).inserted)
        }

        for crown in solution.crowns {
            for other in solution.crowns where other != crown {
                let dr = abs(crown.row - other.row)
                let dc = abs(crown.column - other.column)
                XCTAssertNotEqual(dr, dc)
                XCTAssertFalse(dr == 1 && dc == 1)
            }
        }
    }

    func testSolverUnsatisfiableBoardThrows() {
        let regions = [
            [0, 0, 0],
            [1, 1, 1],
            [2, 2, 2]
        ]
        let board = QueensBoard(size: 3, regions: regions)
        let solver = QueensSolver()

        XCTAssertThrowsError(try solver.solve(board: board)) { error in
            guard case SolverError.unsatisfiable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
