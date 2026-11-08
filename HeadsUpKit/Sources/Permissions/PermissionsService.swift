import AppKit
import ApplicationServices
import AVFoundation
import CoreMotion
import Foundation
import Speech

/// A privacy permission's state, independent of the framework that reports it.
public enum AuthorizationState: String, Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

public typealias MotionAuthorization = AuthorizationState

/// Snapshot of every permission HeadsUp uses.
public struct PermissionStatus: Sendable, Equatable {
    public var accessibilityTrusted: Bool
    public var motion: MotionAuthorization
    public var motionHardwareAvailable: Bool
    public var microphone: AuthorizationState
    public var speechRecognition: AuthorizationState

    public init(accessibilityTrusted: Bool, motion: MotionAuthorization, motionHardwareAvailable: Bool,
                microphone: AuthorizationState = .notDetermined, speechRecognition: AuthorizationState = .notDetermined) {
        self.accessibilityTrusted = accessibilityTrusted
        self.motion = motion
        self.motionHardwareAvailable = motionHardwareAvailable
        self.microphone = microphone
        self.speechRecognition = speechRecognition
    }

    public var isVoiceInputReady: Bool { microphone == .authorized && speechRecognition == .authorized }

    public var isReady: Bool {
        accessibilityTrusted && motion != .denied && motion != .restricted
    }
}

/// Checks and requests the permissions HeadsUp needs.
@MainActor
public protocol PermissionsProviding: AnyObject {
    func currentStatus() -> PermissionStatus
    func promptForAccessibility()
    func openAccessibilitySettings()
    func openMotionSettings()
    func requestMicrophone()
    func requestSpeechRecognition()
    func openMicrophoneSettings()
    func openSpeechRecognitionSettings()
}

/// Reads and requests permissions from macOS.
@MainActor
public final class SystemPermissionsService: PermissionsProviding {
    private let motionManager = CMHeadphoneMotionManager()

    public init() {}

    public func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityTrusted: AXIsProcessTrusted(),
            motion: Self.motionAuthorization(),
            motionHardwareAvailable: motionManager.isDeviceMotionAvailable,
            microphone: Self.microphoneAuthorization(),
            speechRecognition: Self.speechAuthorization())
    }

    public func promptForAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public func openMotionSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy")
    }

    public func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    public func requestSpeechRecognition() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    public func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    public func openSpeechRecognitionSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func motionAuthorization() -> MotionAuthorization {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private static func microphoneAuthorization() -> AuthorizationState {
        captureAuthorization(for: .audio)
    }

    private static func captureAuthorization(for media: AVMediaType) -> AuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private static func speechAuthorization() -> AuthorizationState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
