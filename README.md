# Queens Solver

This repository now contains a SwiftUI-based iOS application prototype for solving Queens puzzles from photographed boards.

## Project Structure

- `Package.swift` – Swift Package manifest exposing the `QueensSolverApp` module for testing and reuse.
- `QueensSolverApp/` – Application sources, including the SwiftUI UI, solver, and Vision-backed image processing pipeline.
- `QueensSolverAppTests/` – XCTest targets validating the solver constraints and exercising the synthetic image recognition pipeline.

## Running the App

Open the repository in Xcode 15 or later and select the *QueensSolverApp* scheme to build and run on an iOS 16 simulator or device. The package manifest allows you to add the folder directly via **File > Add Packages...** if preferred.

The UI lets you import a puzzle photo, previews the normalized board with detected color regions, and overlays the computed crown placements once solved.

## Testing

Execute the unit test suite with:

```bash
xcodebuild test -scheme QueensSolverApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

or, when using Swift Package Manager directly:

```bash
swift test
```

The tests assert solver constraints (unique crowns per row/column/region and diagonal separation) and verify that the image processor can rebuild a board from a synthetic colored grid.
