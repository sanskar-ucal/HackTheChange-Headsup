import AVFoundation
import CoreMedia
import Foundation
import QuartzCore

/// Built-in camera → Vision → `FaceFrame`s on the main actor.
@MainActor
public final class AVCaptureCameraSource: FaceSampleSource {
    public var onFrame: (@MainActor (FaceFrame) -> Void)?
    public var onFailure: (@MainActor (String) -> Void)?
    public var onRunning: (@MainActor () -> Void)?
    public private(set) var isRunning = false

    private let worker = CameraWorker()

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            launch()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self, self.isRunning else { return }
                    if granted { self.launch() } else { self.fail("Camera access was denied.") }
                }
            }
        case .denied, .restricted:
            fail("Camera access is off. Allow HeadsUp in Privacy & Security → Camera.")
        @unknown default:
            fail("Camera access is unavailable.")
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        worker.stop()
    }

    private func launch() {
        worker.start(
            onFrame: { [weak self] frame in
                Task { @MainActor in
                    guard let self, self.isRunning else { return }
                    self.onFrame?(frame)
                }
            },
            onStarted: { [weak self] in
                Task { @MainActor in self?.onRunning?() }
            },
            onError: { [weak self] message in
                Task { @MainActor in self?.fail(message) }
            })
    }

    private func fail(_ message: String) {
        isRunning = false
        worker.stop()
        onFailure?(message)
    }
}

/// Owns the capture session on one serial queue.
final class CameraWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.hackthechange.HeadsUp.camera", qos: .userInteractive)
    private let session = AVCaptureSession()
    private let detector = FaceLandmarkDetector()
    private var onFrame: (@Sendable (FaceFrame) -> Void)?
    private var isConfigured = false

    func start(onFrame: @escaping @Sendable (FaceFrame) -> Void, onStarted: @escaping @Sendable () -> Void,
               onError: @escaping @Sendable (String) -> Void) {
        queue.async { [self] in
            self.onFrame = onFrame
            if !isConfigured {
                if let problem = configure() {
                    onError(problem)
                    return
                }
                isConfigured = true
            }
            session.startRunning()
            if session.isRunning { onStarted() } else { onError("The camera could not start.") }
        }
    }

    func stop() {
        queue.async { [self] in
            onFrame = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() -> String? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            return "No camera found."
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            return "The camera is in use or unavailable."
        }
        session.addInput(input)
        Self.requestFrameRate(30, on: device)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return "The camera output could not be set up." }
        session.addOutput(output)
        return nil
    }

    private static func requestFrameRate(_ fps: Double, on device: AVCaptureDevice) {
        let supported = device.activeFormat.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= fps }
        guard supported, (try? device.lockForConfiguration()) != nil else { return }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.unlockForConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let onFrame, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CACurrentMediaTime()
        let brightness = FaceLandmarkDetector.meanLuma(pixelBuffer)
        let eyes = detector.detect(in: pixelBuffer)
        onFrame(FaceFrame(timestamp: timestamp, brightness: brightness, eyes: eyes))
    }
}
