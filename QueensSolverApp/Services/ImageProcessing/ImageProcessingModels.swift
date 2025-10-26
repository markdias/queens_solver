import CoreGraphics
import Foundation
import UIKit

public struct ImageProcessingResult {
    public let board: QueensBoard
    public let overlays: [RegionOverlay]
    public let normalizedRectangle: [CGPoint]
    public let correctedImage: UIImage
}

public struct RegionOverlay: Identifiable {
    public let id: Int
    public let polygon: [CGPoint]
    public let color: UIColor

    public var displayColor: ColorRepresentation {
        ColorRepresentation(color)
    }
}

public struct ColorRepresentation: Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public enum ImageProcessingError: Error {
    case cgImageMissing
    case gridNotFound
    case perspectiveCorrectionFailed
    case unsupported
}

public struct GridDetectionResult {
    public let correctedImage: CGImage
    public let normalizedQuad: [CGPoint]
    public let expectedSize: Int?

    public init(correctedImage: CGImage, normalizedQuad: [CGPoint], expectedSize: Int? = nil) {
        self.correctedImage = correctedImage
        self.normalizedQuad = normalizedQuad
        self.expectedSize = expectedSize
    }
}
