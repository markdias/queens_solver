import SwiftUI
import UIKit

#if !SWIFT_PACKAGE
@main
struct QueensSolverAppApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
#endif

final class AppModel: ObservableObject {
    @Published var imageProcessingResult: ImageProcessingResult?
    @Published var solverResult: SolverResult = .idle
    @Published var isProcessing: Bool = false

    let imageProcessor = ImageProcessor()
    let solver = QueensSolver()

    func loadImage(_ image: UIImage) {
        isProcessing = true
        solverResult = .idle
        Task {
            do {
                let result = try await imageProcessor.process(image: image)
                await MainActor.run {
                    self.imageProcessingResult = result
                }
                try await solveBoard(from: result)
            } catch {
                await MainActor.run {
                    self.imageProcessingResult = nil
                    self.solverResult = .failed(error.localizedDescription)
                    self.isProcessing = false
                }
            }
        }
    }

    private func solveBoard(from processingResult: ImageProcessingResult) async throws {
        let board = processingResult.board
        let solution = try await Task.detached(priority: .userInitiated) {
            try solver.solve(board: board)
        }.value
        await MainActor.run {
            self.solverResult = .solved(solution)
            self.isProcessing = false
        }
    }
}

enum SolverResult {
    case idle
    case solved(QueensBoard)
    case failed(String)
}
