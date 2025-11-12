import Foundation
import CoreML
import CoreGraphics

/// Lightweight wrapper around the exported YOLO11m CoreML model that returns
/// a single normalized bounding box suitable for the Flutter preview overlay.
final class CoreMLYoloDetector {
    struct Detection {
        let rect: CGRect  // Normalized (0-1) in source frame coordinates
        let confidence: Double
    }

    private struct LetterboxInfo {
        let scale: CGFloat
        let dx: CGFloat
        let dy: CGFloat
        let sourceWidth: CGFloat
        let sourceHeight: CGFloat
        let targetSize: CGSize

        func convertToOriginalRect(centerX: CGFloat,
                                   centerY: CGFloat,
                                   width: CGFloat,
                                   height: CGFloat) -> CGRect? {
            guard sourceWidth > 0, sourceHeight > 0 else { return nil }
            let targetWidth = targetSize.width
            let targetHeight = targetSize.height

            let boxWidth = width * targetWidth
            let boxHeight = height * targetHeight
            if boxWidth <= 1 || boxHeight <= 1 {
                return nil
            }

            let left = centerX * targetWidth - boxWidth / 2.0
            let top = centerY * targetHeight - boxHeight / 2.0

            let adjustedLeft = (left - dx) / scale
            let adjustedTop = (top - dy) / scale
            let adjustedWidth = boxWidth / scale
            let adjustedHeight = boxHeight / scale

            let x0 = max(0, min(sourceWidth, adjustedLeft))
            let y0 = max(0, min(sourceHeight, adjustedTop))
            let x1 = max(0, min(sourceWidth, adjustedLeft + adjustedWidth))
            let y1 = max(0, min(sourceHeight, adjustedTop + adjustedHeight))

            let widthOriginal = x1 - x0
            let heightOriginal = y1 - y0
            if widthOriginal <= 1 || heightOriginal <= 1 {
                return nil
            }

            let normX = max(0, min(1, x0 / sourceWidth))
            let normY = max(0, min(1, y0 / sourceHeight))
            let normW = max(0, min(1, widthOriginal / sourceWidth))
            let normH = max(0, min(1, heightOriginal / sourceHeight))
            return CGRect(x: normX, y: normY, width: normW, height: normH)
        }
    }

    private let model: MLModel
    private let imageConstraint: MLImageConstraint
    private let confidenceThreshold: Double
    private let iouThreshold: Double
    private let allowedClassIndices: [Int]
    private let targetSize = CGSize(width: 640, height: 640)

    init?(bundle: Bundle = .main,
          confidenceThreshold: Double = 0.35,
          iouThreshold: Double = 0.45,
          allowedClassIndices: [Int] = [0]) {
        guard let modelURL = CoreMLYoloDetector.locateModel(in: bundle) else {
            NSLog("[YOLO] Unable to locate yolo11m CoreML package in bundle resources")
            return nil
        }

        do {
            model = try MLModel(contentsOf: modelURL)
        } catch {
            NSLog("[YOLO] Failed to load yolo11m CoreML model: \(error.localizedDescription)")
            return nil
        }

        guard let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            NSLog("[YOLO] CoreML model is missing image constraint metadata")
            return nil
        }

        imageConstraint = constraint
        self.confidenceThreshold = confidenceThreshold
        self.iouThreshold = iouThreshold
        self.allowedClassIndices = allowedClassIndices
    }

    func detectStrongestFace(in frameData: Data, width: Int, height: Int) -> Detection? {
        guard let rgbImage = CoreMLYoloDetector.makeRGBImage(from: frameData, width: width, height: height) else {
            return nil
        }
        guard let (letterboxedImage, letterbox) = CoreMLYoloDetector.makeLetterboxedImage(from: rgbImage, targetSize: targetSize) else {
            return nil
        }

        guard let imageValue = try? MLFeatureValue(cgImage: letterboxedImage, constraint: imageConstraint, options: [:]) else {
            return nil
        }

        let inputs: [String: MLFeatureValue] = [
            "image": imageValue,
            "confidenceThreshold": MLFeatureValue(double: confidenceThreshold),
            "iouThreshold": MLFeatureValue(double: iouThreshold)
        ]

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: inputs) else {
            return nil
        }

        guard let output = try? model.prediction(from: provider),
              let confidenceArray = output.featureValue(for: "confidence")?.multiArrayValue,
              let coordinatesArray = output.featureValue(for: "coordinates")?.multiArrayValue else {
            return nil
        }

        return CoreMLYoloDetector.parseBestDetection(
            confidenceArray: confidenceArray,
            coordinatesArray: coordinatesArray,
            allowedClasses: allowedClassIndices,
            letterbox: letterbox,
            minConfidence: Float(confidenceThreshold)
        )
    }

    private static func locateModel(in bundle: Bundle) -> URL? {
        if let url = bundle.url(forResource: "yolo11m", withExtension: "mlpackage") {
            return url
        }
        // In development builds we sometimes rely on the Runner/Resources folder directly.
        let resourceBundleURL = bundle.bundleURL.appendingPathComponent("Contents/Resources/yolo11m.mlpackage")
        if FileManager.default.fileExists(atPath: resourceBundleURL.path) {
            return resourceBundleURL
        }
        return nil
    }

    private static func makeRGBImage(from data: Data, width: Int, height: Int) -> CGImage? {
        let expectedCount = width * height * 3
        guard data.count >= expectedCount else {
            return nil
        }

        let bytesPerRow = width * 3
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func makeLetterboxedImage(from image: CGImage,
                                             targetSize: CGSize) -> (CGImage, LetterboxInfo)? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(targetSize.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.setFillColor(red: 114.0 / 255.0, green: 114.0 / 255.0, blue: 114.0 / 255.0, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: targetSize))

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        let scale = min(targetSize.width / sourceWidth, targetSize.height / sourceHeight)
        let scaledWidth = sourceWidth * scale
        let scaledHeight = sourceHeight * scale
        let dx = (targetSize.width - scaledWidth) / 2.0
        let dy = (targetSize.height - scaledHeight) / 2.0

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: dx, y: dy, width: scaledWidth, height: scaledHeight))

        guard let letterboxedImage = context.makeImage() else {
            return nil
        }

        let info = LetterboxInfo(
            scale: scale,
            dx: dx,
            dy: dy,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            targetSize: targetSize
        )
        return (letterboxedImage, info)
    }

    private static func parseBestDetection(confidenceArray: MLMultiArray,
                                           coordinatesArray: MLMultiArray,
                                           allowedClasses: [Int],
                                           letterbox: LetterboxInfo,
                                           minConfidence: Float) -> Detection? {
        guard let detectionCountNumber = confidenceArray.shape.first,
              confidenceArray.shape.count >= 2 else {
            return nil
        }

        let detectionCount = detectionCountNumber.intValue
        let classCount = confidenceArray.shape[1].intValue
        guard detectionCount > 0, classCount > 0 else {
            return nil
        }

        let filteredClasses = allowedClasses.filter { $0 < classCount }
        guard !filteredClasses.isEmpty else {
            return nil
        }

        let confPtr = confidenceArray.dataPointer.bindMemory(to: Float32.self, capacity: detectionCount * classCount)
        let coordsPtr = coordinatesArray.dataPointer.bindMemory(to: Float32.self, capacity: detectionCount * 4)

        var bestDetection: Detection?

        for det in 0..<detectionCount {
            var bestScore: Float32 = 0
            for classIndex in filteredClasses {
                let idx = det * classCount + classIndex
                let score = confPtr[idx]
                if score > bestScore {
                    bestScore = score
                }
            }

            if bestScore < minConfidence {
                continue
            }

            let base = det * 4
            let cx = CGFloat(coordsPtr[base])
            let cy = CGFloat(coordsPtr[base + 1])
            let width = CGFloat(coordsPtr[base + 2])
            let height = CGFloat(coordsPtr[base + 3])

            guard let rect = letterbox.convertToOriginalRect(centerX: cx, centerY: cy, width: width, height: height) else {
                continue
            }

            let detection = Detection(rect: rect, confidence: Double(bestScore))
            if let currentBest = bestDetection {
                if detection.confidence > currentBest.confidence {
                    bestDetection = detection
                }
            } else {
                bestDetection = detection
            }
        }

        return bestDetection
    }
}
