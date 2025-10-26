import CoreImage
import Foundation
import UIKit
#if canImport(Vision)
import Vision
#endif

public protocol GridRecognizer {
    func detectGrid(in image: CGImage) throws -> GridDetectionResult
}

public final class ImageProcessor {
    private let recognizer: GridRecognizer
    private let ciContext: CIContext
    private let queue = DispatchQueue(label: "ImageProcessor.queue", qos: .userInitiated)

    public init(recognizer: GridRecognizer? = nil, ciContext: CIContext = CIContext()) {
        if let recognizer {
            self.recognizer = recognizer
        } else if let visionRecognizer = VisionGridRecognizer.makeDefault() {
            self.recognizer = visionRecognizer
        } else {
            self.recognizer = FallbackGridRecognizer()
        }
        self.ciContext = ciContext
    }

    public func process(image: UIImage) async throws -> ImageProcessingResult {
        guard let cgImage = image.cgImage else {
            throw ImageProcessingError.cgImageMissing
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let detection = try self.recognizer.detectGrid(in: cgImage)
                    let regions = try self.segmentRegions(from: detection.correctedImage, expectedSize: detection.expectedSize)
                    let overlays = self.buildOverlays(from: regions, size: detection.correctedImage.width)
                    let board = QueensBoard(size: regions.count, regions: regions)
                    let correctedUIImage = UIImage(cgImage: detection.correctedImage)
                    let result = ImageProcessingResult(board: board,
                                                        overlays: overlays,
                                                        normalizedRectangle: detection.normalizedQuad,
                                                        correctedImage: correctedUIImage)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func segmentRegions(from cgImage: CGImage, expectedSize: Int?) throws -> [[Int]] {
        let ciImage = CIImage(cgImage: cgImage)
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cellCount = expectedSize ?? estimateGridSize(from: cgImage)
        guard cellCount > 0 else { throw ImageProcessingError.unsupported }
        let cellWidth = max(width / CGFloat(cellCount), 1)
        let cellHeight = max(height / CGFloat(cellCount), 1)

        var regionAssignments: [[Int]] = Array(repeating: Array(repeating: 0, count: cellCount), count: cellCount)
        var colorSamples: [UIColor] = []

        for row in 0..<cellCount {
            for column in 0..<cellCount {
                let rect = CGRect(x: CGFloat(column) * cellWidth,
                                  y: CGFloat(row) * cellHeight,
                                  width: cellWidth,
                                  height: cellHeight)
                if let color = try averageColor(in: ciImage, rect: rect) {
                    let (regionIndex, _) = closestRegionColor(to: color, existing: colorSamples)
                    if regionIndex == colorSamples.count {
                        colorSamples.append(color)
                    }
                    regionAssignments[row][column] = regionIndex
                }
            }
        }

        return regionAssignments
    }

    private func closestRegionColor(to color: UIColor, existing: [UIColor]) -> (Int, CGFloat) {
        guard !existing.isEmpty else { return (0, .zero) }
        var bestIndex = existing.count
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, candidate) in existing.enumerated() {
            let distance = color.euclideanDistance(to: candidate)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        if bestDistance > 0.15 {
            return (existing.count, bestDistance)
        }
        return (bestIndex, bestDistance)
    }

    private func averageColor(in image: CIImage, rect: CGRect) throws -> UIColor? {
        let filter = CIFilter.areaAverage()
        filter.inputImage = image.cropped(to: rect)
        guard let output = filter.outputImage else { return nil }
        let extent = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let cgImage = ciContext.createCGImage(output, from: extent) else { return nil }
        let bitmap = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        defer { bitmap.deallocate() }
        let context = CGContext(data: bitmap,
                                width: 1,
                                height: 1,
                                bitsPerComponent: 8,
                                bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        let alpha = CGFloat(bitmap[3]) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func buildOverlays(from regions: [[Int]], size: Int) -> [RegionOverlay] {
        let cellCount = regions.count
        guard cellCount > 0 else { return [] }
        let cellSize = CGFloat(size) / CGFloat(cellCount)
        var overlays: [RegionOverlay] = []
        let uniqueRegions = Set(regions.flatMap { $0 })
        for regionID in uniqueRegions.sorted() {
            let polygon = polygonForRegion(regionID, in: regions, cellSize: cellSize)
            let color = UIColor.randomDistinctColor(seed: regionID + 1)
            overlays.append(RegionOverlay(id: regionID, polygon: polygon, color: color))
        }
        return overlays
    }

    private func polygonForRegion(_ region: Int, in regions: [[Int]], cellSize: CGFloat) -> [CGPoint] {
        var minRow = Int.max
        var maxRow = Int.min
        var minCol = Int.max
        var maxCol = Int.min

        for (rowIndex, row) in regions.enumerated() {
            for (columnIndex, value) in row.enumerated() where value == region {
                minRow = min(minRow, rowIndex)
                maxRow = max(maxRow, rowIndex)
                minCol = min(minCol, columnIndex)
                maxCol = max(maxCol, columnIndex)
            }
        }

        guard minRow <= maxRow, minCol <= maxCol else { return [] }

        let minX = CGFloat(minCol) * cellSize
        let maxX = CGFloat(maxCol + 1) * cellSize
        let minY = CGFloat(minRow) * cellSize
        let maxY = CGFloat(maxRow + 1) * cellSize

        return [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY)
        ]
    }

    private func estimateGridSize(from image: CGImage) -> Int {
        let minDimension = min(image.width, image.height)
        if minDimension > 1500 {
            return 10
        } else if minDimension > 900 {
            return 8
        } else if minDimension > 600 {
            return 7
        } else if minDimension > 400 {
            return 6
        } else {
            return 5
        }
    }
}

private final class FallbackGridRecognizer: GridRecognizer {
    func detectGrid(in image: CGImage) throws -> GridDetectionResult {
        return GridDetectionResult(correctedImage: image, normalizedQuad: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ])
    }
}

#if canImport(Vision)
private final class VisionGridRecognizer: GridRecognizer {
    private let ciContext: CIContext

    private init(ciContext: CIContext) {
        self.ciContext = ciContext
    }

    static func makeDefault() -> GridRecognizer? {
        return VisionGridRecognizer(ciContext: CIContext())
    }

    func detectGrid(in image: CGImage) throws -> GridDetectionResult {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.8
        request.maximumAspectRatio = 1.2
        request.minimumConfidence = 0.5

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNRectangleObservation else {
            throw ImageProcessingError.gridNotFound
        }
        let correctedImage = try perspectiveCorrect(image: image, observation: observation)
        let quad = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
        return GridDetectionResult(correctedImage: correctedImage, normalizedQuad: quad)
    }

    private func perspectiveCorrect(image: CGImage, observation: VNRectangleObservation) throws -> CGImage {
        let ciImage = CIImage(cgImage: image)
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        let transform = CIFilter.perspectiveCorrection()
        transform.inputImage = ciImage
        transform.topLeft = observation.topLeft.scaled(width: width, height: height)
        transform.topRight = observation.topRight.scaled(width: width, height: height)
        transform.bottomLeft = observation.bottomLeft.scaled(width: width, height: height)
        transform.bottomRight = observation.bottomRight.scaled(width: width, height: height)
        guard let output = transform.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            throw ImageProcessingError.perspectiveCorrectionFailed
        }
        return cgImage
    }
}
#endif

private extension CGPoint {
    func scaled(width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: x * width, y: (1 - y) * height)
    }
}

private extension UIColor {
    static func randomDistinctColor(seed: Int) -> UIColor {
        let value = abs(seed &* 1_103_515_245 &+ 12_345) % 1_000
        let hue = CGFloat(value) / 1000.0
        let saturation: CGFloat = 0.6
        let brightness: CGFloat = 0.8
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 0.5)
    }

    func euclideanDistance(to other: UIColor) -> CGFloat {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2
        return sqrt(dr * dr + dg * dg + db * db)
    }
}
