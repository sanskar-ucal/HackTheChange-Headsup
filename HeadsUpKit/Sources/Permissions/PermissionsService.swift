import AppKit
import ApplicationServices
import AVFoundation
import CoreMotion
import Foundation
import Speech

public enum AuthorizationState: String, Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

public typealias MotionAuthorization = AuthorizationState

public struct PermissionStatus: Sendable, Equatable {
    public var accessibilityTrusted: Bool
    public var motion: MotionAuthorization
    /// Whether this Mac supports headphone motion at all (`isDeviceMotionAvailable`).
    public var motionHardwareAvailable: Bool
    /// Voice input only; not required for head pointing.
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

    /// Motion `notDetermined` counts as ready: the system prompt appears when motion
    /// updates start, and HeadsUp starts them as soon as it launches.
    public var isReady: Bool {
        accessibilityTrusted && motion != .denied && motion != .restricted
    }
}

/// Checks and requests the permissions HeadsUp needs.
@MainActor
public protocol PermissionsProviding: AnyObject {
    func currentStatus() -> PermissionStatus
    /// Shows the system "allow accessibility" prompt (once per app identity).
    func promptForAccessibility()
    func openAccessibilitySettings()
    func openMotionSettings()
    func requestMicrophone()
    func requestSpeechRecognition()
    func openMicrophoneSettings()
    func openSpeechRecognitionSettings()
}

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
        // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public func openMotionSettings() {
        // macOS has no dedicated deep link for headphone motion; open Privacy & Security.
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
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
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
