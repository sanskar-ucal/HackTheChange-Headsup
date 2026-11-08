import AVFoundation
import CoreMedia
import Foundation
import OSLog
import QuartzCore

/// Built-in camera → Vision → `FaceFrame`s on the main actor.
@MainActor
public final class AVCaptureCameraSource: FaceSampleSource {
    public var onFrame: (@MainActor (FaceFrame) -> Void)?
    public var onFailure: (@MainActor (String) -> Void)?
    public var onRunning: (@MainActor () -> Void)?
    public var onLog: (@MainActor (String) -> Void)?
    public private(set) var isRunning = false

    private let worker = CameraWorker()

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        log("camera permission: \(Self.describe(status))")
        switch status {
        case .authorized:
            launch()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self, self.isRunning else { return }
                    self.log("camera permission request: \(granted ? "granted" : "denied")")
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
            },
            onLog: { [weak self] line in
                Task { @MainActor in self?.log(line) }
            })
    }

    private func log(_ line: String) {
        Self.logger.info("\(line, privacy: .public)")
        onLog?(line)
    }

    private static let logger = Logger(subsystem: "com.hackthechange.HeadsUp", category: "camera")

    private static func describe(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .notDetermined: return "not determined (asking)"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
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
    private var onLog: (@Sendable (String) -> Void)?
    private var isConfigured = false

    func start(onFrame: @escaping @Sendable (FaceFrame) -> Void, onStarted: @escaping @Sendable () -> Void,
               onError: @escaping @Sendable (String) -> Void, onLog: @escaping @Sendable (String) -> Void) {
        queue.async { [self] in
            self.onFrame = onFrame
            self.onLog = onLog
            if !isConfigured {
                if let problem = configure() {
                    onLog("camera setup failed: \(problem)")
                    onError(problem)
                    return
                }
                isConfigured = true
            }
            session.startRunning()
            onLog("camera session running: \(session.isRunning)")
            if session.isRunning { onStarted() } else { onError("The camera could not start.") }
        }
    }

    func stop() {
        queue.async { [self] in
            onFrame = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Builds input and output in one configuration; on failure the session is emptied so a retry starts clean.
    private func configure() -> String? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        let problem = addInputAndOutput()
        if problem != nil {
            session.inputs.forEach(session.removeInput)
            session.outputs.forEach(session.removeOutput)
        }
        return problem
    }

    private func addInputAndOutput() -> String? {
        guard let device = Self.findCamera() else { return "No camera found." }
        onLog?("camera device: \(device.localizedName) (\(device.deviceType.rawValue))")
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return "The camera is unavailable: \(error.localizedDescription)"
        }
        guard session.canAddInput(input) else { return "The camera is in use by another app." }
        session.addInput(input)
        // Many built-in cameras have no 640x480 format, so the preset is chosen only once the input exists.
        session.sessionPreset = session.canSetSessionPreset(.vga640x480) ? .vga640x480 : .high
        Self.requestFrameRate(30, on: device)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: 640,
            kCVPixelBufferHeightKey as String: 480,
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return "The camera output could not be set up." }
        session.addOutput(output)
        return nil
    }

    /// Mac cameras report position `.unspecified`; prefer the built-in one, then any other.
    private static func findCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified)
        let devices = discovery.devices
        return devices.first { $0.deviceType == .builtInWideAngleCamera }
            ?? devices.first
            ?? AVCaptureDevice.default(for: .video)
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
