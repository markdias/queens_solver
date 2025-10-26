import XCTest
import CoreImage
import UIKit
@testable import QueensSolverApp

final class ImageProcessorTests: XCTestCase {
    func testProcessesSyntheticBoard() async throws {
        let boardSize = 4
        let image = makeSyntheticBoard(size: boardSize)
        let recognizer = MockGridRecognizer(image: image, expectedSize: boardSize)
        let processor = ImageProcessor(recognizer: recognizer)
        let result = try await processor.process(image: UIImage(cgImage: image))

        XCTAssertEqual(result.board.size, boardSize)
        XCTAssertEqual(result.board.regions.flatMap { $0 }.max(), boardSize - 1)
    }

    private func makeSyntheticBoard(size: Int) -> CGImage {
        let cellSize = 40
        let dimension = size * cellSize
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil,
                                width: dimension,
                                height: dimension,
                                bitsPerComponent: 8,
                                bytesPerRow: dimension * 4,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for row in 0..<size {
            for column in 0..<size {
                let color = UIColor(hue: CGFloat(row * size + column) / CGFloat(size * size),
                                     saturation: 0.8,
                                     brightness: 0.9,
                                     alpha: 1.0).cgColor
                context.setFillColor(color)
                let rect = CGRect(x: column * cellSize, y: row * cellSize, width: cellSize, height: cellSize)
                context.fill(rect)
            }
        }
        return context.makeImage()!
    }
}

private final class MockGridRecognizer: GridRecognizer {
    private let image: CGImage
    private let expectedSize: Int

    init(image: CGImage, expectedSize: Int) {
        self.image = image
        self.expectedSize = expectedSize
    }

    func detectGrid(in image: CGImage) throws -> GridDetectionResult {
        return GridDetectionResult(correctedImage: self.image,
                                   normalizedQuad: [
                                       CGPoint(x: 0, y: 0),
                                       CGPoint(x: 1, y: 0),
                                       CGPoint(x: 1, y: 1),
                                       CGPoint(x: 0, y: 1)
                                   ],
                                   expectedSize: expectedSize)
    }
}
