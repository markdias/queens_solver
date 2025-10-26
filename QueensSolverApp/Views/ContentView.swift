import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label("Import Board Photo", systemImage: "photo")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(12)
                }
                .onChange(of: selectedItem) { newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                            appModel.loadImage(image)
                        }
                    }
                }

                if let image = selectedImage {
                    let displayImage = appModel.imageProcessingResult?.correctedImage ?? image
                    let overlays = appModel.imageProcessingResult?.overlays ?? []
                    let referenceSize = appModel.imageProcessingResult?.correctedImage.size ?? image.size
                    BoardPreview(image: displayImage,
                                 overlays: overlays,
                                 referenceSize: referenceSize)
                        .frame(height: 320)
                        .overlay(
                            Group {
                                if appModel.isProcessing {
                                    ProgressView("Analyzing…")
                                }
                            }
                        )
                } else {
                    Text("Import a puzzle board to begin.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                }

                SolverResultView(result: appModel.solverResult)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding()
            .navigationTitle("Queens Solver")
        }
    }
}

private struct BoardPreview: View {
    let image: UIImage
    let overlays: [RegionOverlay]
    let referenceSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                ForEach(overlays) { overlay in
                    RegionOverlayView(overlay: overlay,
                                      geometrySize: geometry.size,
                                      referenceSize: referenceSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

private struct RegionOverlayView: View {
    let overlay: RegionOverlay
    let geometrySize: CGSize
    let referenceSize: CGSize

    var body: some View {
        Path { path in
            guard !overlay.polygon.isEmpty else { return }
            let scaleX = geometrySize.width / max(referenceSize.width, 1)
            let scaleY = geometrySize.height / max(referenceSize.height, 1)
            path.addLines(overlay.polygon.map { point in
                CGPoint(x: point.x * scaleX, y: point.y * scaleY)
            })
            path.closeSubpath()
        }
        .fill(Color(uiColor: overlay.color).opacity(0.25))
        .overlay(
            Path { path in
                guard !overlay.polygon.isEmpty else { return }
                let scaleX = geometrySize.width / max(referenceSize.width, 1)
                let scaleY = geometrySize.height / max(referenceSize.height, 1)
                path.addLines(overlay.polygon.map { point in
                    CGPoint(x: point.x * scaleX, y: point.y * scaleY)
                })
                path.closeSubpath()
            }
            .stroke(Color(uiColor: overlay.color), lineWidth: 2)
        )
    }
}

private struct SolverResultView: View {
    let result: SolverResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result {
            case .idle:
                Text("Awaiting puzzle input.")
                    .foregroundColor(.secondary)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            case .solved(let board):
                Text("Solution Found")
                    .font(.headline)
                QueensBoardView(board: board)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct QueensBoardView: View {
    let board: QueensBoard

    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / CGFloat(board.size)
            ZStack(alignment: .topLeading) {
                ForEach(0..<board.size, id: \.self) { row in
                    ForEach(0..<board.size, id: \.self) { column in
                        let position = Position(row: row, column: column)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.4))
                            .frame(width: cellSize, height: cellSize)
                            .position(x: CGFloat(column) * cellSize + cellSize / 2,
                                      y: CGFloat(row) * cellSize + cellSize / 2)
                        if board.crowns.contains(position) {
                            Text("👑")
                                .font(.system(size: cellSize * 0.6))
                                .frame(width: cellSize, height: cellSize)
                                .position(x: CGFloat(column) * cellSize + cellSize / 2,
                                          y: CGFloat(row) * cellSize + cellSize / 2)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppModel())
    }
}
