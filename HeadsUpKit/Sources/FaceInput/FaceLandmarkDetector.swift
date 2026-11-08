import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Runs Vision face landmarks on one frame and reduces it to an `EyeSample`.
final class FaceLandmarkDetector {
    private let request: VNDetectFaceLandmarksRequest

    init() {
        request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
    }

    func detect(in pixelBuffer: CVPixelBuffer) -> EyeSample? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        // The largest face is the person in front of the Mac.
        guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let landmarks = face.landmarks,
              let left = landmarks.leftEye,
              let right = landmarks.rightEye
        else { return nil }

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let yawRadians = face.yaw?.doubleValue ?? 0
        return EyeSample(
            leftEAR: EyeAspectRatio.compute(left.pointsInImage(imageSize: size)),
            rightEAR: EyeAspectRatio.compute(right.pointsInImage(imageSize: size)),
            confidence: Double(min(face.confidence, landmarks.confidence)),
            faceYawDegrees: yawRadians * 180 / .pi,
            faceSize: Double(face.boundingBox.width))
    }

    /// Mean luma from the Y plane, sampled sparsely; 0 = black, 1 = white.
    static func meanLuma(_ pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        else { return 1 }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var total = 0
        var count = 0
        for y in Swift.stride(from: 0, to: height, by: 16) {
            for x in Swift.stride(from: 0, to: width, by: 16) {
                total += Int(bytes[y * stride + x])
                count += 1
            }
        }
        return count > 0 ? Double(total) / Double(count) / 255 : 1
    }
}
