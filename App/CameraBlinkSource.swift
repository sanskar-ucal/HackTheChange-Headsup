import AVFoundation
import CoreMedia
import Foundation
import HeadsUpKit
import QuartzCore
import Vision

/// Camera adapter for blink gestures: finds the user's face and reports how open the eyes
/// are. Frames are analyzed in memory on this Mac and dropped; nothing is stored, sent or
/// used to identify anyone. Open/closed classification and blink sequences live in
/// HeadsUpKit (`EyeOpennessClassifier`, `BlinkSequenceRecognizer`).
@MainActor
final class CameraBlinkSource: BlinkSource {
    private var capture: CameraCapture?
    private var handler: (@MainActor @Sendable (BlinkSourceEvent) -> Void)?

    var authorization: AuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestAccess(_ completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(granted) } }
        }
    }

    func start(onEvent: @escaping @MainActor @Sendable (BlinkSourceEvent) -> Void) {
        handler = onEvent
        if capture == nil {
            capture = CameraCapture { [weak self] event in
                // One serial hop per event keeps status and frames in order.
                DispatchQueue.main.async { [weak self] in MainActor.assumeIsolated { self?.handler?(event) } }
            }
        }
        capture?.start()
    }

    func stop() {
        handler = nil
        capture?.stop()
    }
}

/// Owns the capture session and Vision work off the main thread.
///
/// Queue discipline: session state is confined to `sessionQueue`, Vision state to
/// `visionQueue`; that confinement is what makes `@unchecked Sendable` sound.
private final class CameraCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let emit: @Sendable (BlinkSourceEvent) -> Void
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "HeadsUp.camera.session")
    private let visionQueue = DispatchQueue(label: "HeadsUp.camera.vision", qos: .userInitiated)

    // sessionQueue only
    private var wantsCapture = false
    private var input: AVCaptureDeviceInput?
    private var observers: [NSObjectProtocol] = []

    // visionQueue only
    private var lastAnalysis: TimeInterval = -.infinity
    private let request = VNDetectFaceLandmarksRequest()

    /// Caps Vision work at about 30 analyses per second.
    private static let minAnalysisInterval: TimeInterval = 1.0 / 32
    /// Beyond this head yaw (radians) eye landmarks get unreliable.
    private static let maxFaceYaw = 0.7

    init(emit: @escaping @Sendable (BlinkSourceEvent) -> Void) {
        self.emit = emit
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            sessionQueue.async { self.handleRuntimeError() }
        })
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let self else { return }
            let uniqueID = (note.object as? AVCaptureDevice)?.uniqueID
            sessionQueue.async { self.handleDisconnect(uniqueID: uniqueID) }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func start() {
        sessionQueue.async { [self] in
            wantsCapture = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureAndStart()
            case .notDetermined:
                emit(.status(.requestingAccess))
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self else { return }
                    sessionQueue.async {
                        guard self.wantsCapture else { return }
                        if granted { self.configureAndStart() } else { self.emit(.status(.denied)) }
                    }
                }
            case .denied:
                emit(.status(.denied))
            case .restricted:
                emit(.status(.restricted))
            @unknown default:
                emit(.status(.denied))
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            wantsCapture = false
            if session.isRunning { session.stopRunning() }
        }
    }

    /// sessionQueue only; `startRunning()` blocks, so never on the main thread.
    private func configureAndStart() {
        guard wantsCapture else { return }
        emit(.status(.starting))
        if input == nil {
            guard let camera = AVCaptureDevice.systemPreferredCamera ?? AVCaptureDevice.default(for: .video),
                  let newInput = try? AVCaptureDeviceInput(device: camera) else {
                emit(.status(.noCamera))
                return
            }
            session.beginConfiguration()
            session.sessionPreset = session.canSetSessionPreset(.vga640x480) ? .vga640x480 : .medium
            guard session.canAddInput(newInput) else {
                session.commitConfiguration()
                emit(.status(.failed))
                return
            }
            session.addInput(newInput)
            if !session.outputs.contains(output) {
                guard session.canAddOutput(output) else {
                    session.removeInput(newInput)
                    session.commitConfiguration()
                    emit(.status(.failed))
                    return
                }
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self, queue: visionQueue)
                session.addOutput(output)
            }
            session.commitConfiguration()
            input = newInput
        }
        if !session.isRunning { session.startRunning() }
        emit(.status(session.isRunning ? .running : .failed))
    }

    private func handleRuntimeError() {
        guard wantsCapture else { return }
        emit(.status(.failed))
    }

    private func handleDisconnect(uniqueID: String?) {
        guard let input, input.device.uniqueID == uniqueID else { return }
        session.beginConfiguration()
        session.removeInput(input)
        session.commitConfiguration()
        self.input = nil
        if session.isRunning { session.stopRunning() }
        if wantsCapture { emit(.status(.noCamera)) }
    }

    // MARK: Vision (visionQueue)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        // Capture timestamps are host time, the same timebase as CACurrentMediaTime.
        let now = presentation.isValid ? presentation.seconds : CACurrentMediaTime()
        guard now - lastAnalysis >= Self.minAnalysisInterval else { return }
        lastAnalysis = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        let reading: EyeReading
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:]).perform([request])
            reading = Self.reading(from: request.results ?? [], imageSize: size)
        } catch {
            reading = .eyesNotFound
        }
        emit(.observation(EyeObservation(timestamp: now, reading: reading)))
    }

    private static func reading(from faces: [VNFaceObservation], imageSize: CGSize) -> EyeReading {
        guard !faces.isEmpty else { return .noFace }
        let areas = faces.map { Double($0.boundingBox.width * $0.boundingBox.height) }
        guard let index = DominantFace.index(ofAreas: areas) else { return .multipleFaces }
        let face = faces[index]
        if let yaw = face.yaw?.doubleValue, abs(yaw) > maxFaceYaw { return .eyesNotFound }
        guard let landmarks = face.landmarks,
              let left = landmarks.leftEye.flatMap({ eyeAspectRatio($0, imageSize: imageSize) }),
              let right = landmarks.rightEye.flatMap({ eyeAspectRatio($0, imageSize: imageSize) }) else {
            return .eyesNotFound
        }
        // The larger openness means BOTH eyes must close to register a blink.
        return .eyes(openness: max(left, right))
    }

    /// Height ÷ width of the eye contour in image pixels (normalized landmark points are
    /// relative to the face box, whose aspect ratio varies frame to frame).
    private static func eyeAspectRatio(_ region: VNFaceLandmarkRegion2D, imageSize: CGSize) -> Double? {
        let points = region.pointsInImage(imageSize: imageSize)
        guard points.count >= 4 else { return nil }
        let xs = points.map { Double($0.x) }
        let ys = points.map { Double($0.y) }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max(),
              maxX - minX > 1 else { return nil }
        return (maxY - minY) / (maxX - minX)
    }
}
