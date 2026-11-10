import Foundation

/// Every tunable number in HeadsUp.
public struct HeadsUpSettings: Codable, Equatable, Sendable {
    // MARK: Pointing
    /// 0.25…1.5.
    public var sensitivity: Double = 0.6
    /// false = map to the main display only; true = map to the union of all displays.
    public var spanAllDisplays: Bool = false

    // MARK: Rendering
    /// Critically damped spring stiffness (ω²). 22000 settles (2 %) in about 39 ms.
    public var pointerSpringStiffness: Double = 22000
    /// Dead zone: if the target is closer than this (points) to the cursor, it doesn't move.
    public var pointerDeadZonePoints: Double = 3
    /// Moves smaller than this (points) are not posted.
    public var minMoveDistance: Double = 0.5
    /// Pause/resume/recenter glide.
    public var glideDuration: Double = 0.15
    /// After a nod click the cursor stays frozen this long ("Hold after click").
    public var holdAfterClick: Double = 0.4
    /// Glide from the frozen spot back to the head-pointed position after a nod.
    public var releaseGlideDuration: Double = 0.12

    // MARK: Smoothing (One Euro filter)
    public var filterMinCutoff: Double = 1.0
    public var filterBeta: Double = 0.007
    public var filterDCutoff: Double = 1.0

    // MARK: Axis conventions (flip if the hardware reports the opposite sign)
    public var invertYaw: Bool = false
    public var invertPitch: Bool = false
    public var invertRoll: Bool = false

    // MARK: Nod / shake / double nod
    public var gestureOnsetRateDegPerSec: Double = 60
    public var gestureCrossAxisMaxDegPerSec: Double = 45
    public var nodWindow: Double = 0.7
    public var nodMinAmplitudeDegrees: Double = 8
    public var shakeWindow: Double = 0.9
    public var shakeMinAmplitudeDegrees: Double = 10
    public var shakeMinDirectionChanges: Int = 2
    public var gestureCooldown: Double = 0.6
    /// The rollback point is taken this long before the gesture onset.
    public var gestureOnsetLookback: Double = 0.1
    public var cursorHistoryDuration: Double = 0.6
    /// Raw pitch-dominant head speed at which the cursor already stops following, so the first samples of a nod.
    public var nodPreHoldRateDegPerSec: Double = 30
    /// Double nod toggles in-place scroll mode.
    public var doubleNodEnabled: Bool = false
    /// Both nods must start within this window.
    public var doubleNodWindow: Double = 0.9
    /// After a nod finishes, wait this long for a second nod before clicking.
    public var doubleNodWait: Double = 0.25

    // MARK: Blink gestures (camera)
    /// Double blink clicks, triple blink presses Escape. Off by default: the camera only
    /// runs while this is on and HeadsUp is in use (not paused or calibrating).
    public var blinkGesturesEnabled: Bool = false
    /// Longest eyes-open time between blinks of a double/triple blink. A double blink
    /// clicks after waiting this long for a possible third.
    public var blinkSequenceWindow: Double = 0.5
    /// Eye closures shorter than this are ignored (quick reflex blinks, tracking noise).
    public var blinkMinClosure: Double = 0.1
    /// Eye closures longer than this are resting, not blinking.
    public var blinkMaxClosure: Double = 0.45
    public var blinkCooldown: Double = 0.85
    /// Eyes count as closed below this fraction of the learned open-eye size…
    public var blinkClosedRatio: Double = 0.55
    /// …and open again above this fraction.
    public var blinkReopenRatio: Double = 0.75

    // MARK: Tilt-hold
    public var tiltThresholdDegrees: Double = 20
    public var tiltHoldDuration: Double = 1.5
    public var tiltReleaseFraction: Double = 0.5

    // MARK: Calibration, practice & recentering
    public var calibrationDwellDuration: Double = 1.5
    public var calibrationDwellToleranceDegrees: Double = 2.0
    public var calibrationMinMoveDegrees: Double = 4.0
    public var calibrationMinRangeDegrees: Double = 5.0
    public var calibrationTargetInset: Double = 0.05
    public var autoRecenterStillDuration: Double = 2.0
    public var autoRecenterToleranceDegrees: Double = 1.5
    /// Each capture is the median raw pose over this final part of the dwell.
    public var calibrationCaptureWindow: Double = 0.75
    /// A capture is only accepted if the head turned slower than this throughout the window.
    public var calibrationMaxCaptureRateDegPerSec: Double = 5
    /// If the final center re-check differs from the first center by more than this, redo.
    public var calibrationCenterDriftDegrees: Double = 3
    /// Practice never changes sensitivity on its own; it only suggests (nod to accept).
    public var practiceEnabled: Bool = false
    public var practiceDuration: Double = 20
    /// Practice target radius as a fraction of the screen height.
    public var practiceTargetRadius: Double = 0.08

    // MARK: Scrolling
    public var edgeScrollEnabled: Bool = true
    public var horizontalEdgeScroll: Bool = false
    /// On: looking up reveals content above.
    public var naturalScrolling: Bool = true
    /// Multiplier on scroll speed (slider).
    public var scrollSpeed: Double = 1.0
    /// Points per second at full tilt, before `scrollSpeed`.
    public var scrollMaxSpeed: Double = 1500
    public var scrollEngageOvershootDegrees: Double = 3
    /// Degrees past the engage point to reach full speed.
    public var scrollRampDegrees: Double = 10
    /// Edge-push starts at this share of full speed as soon as it engages (0.08 ≈ 120 pt/s).
    public var scrollEngageMinFraction: Double = 0.08
    public var scrollModeNeutralDegrees: Double = 2
    public var scrollModeRampDegrees: Double = 12
    /// Scroll mode captures its neutral pose this long after the double nod.
    public var scrollModeSettleTime: Double = 0.4
    /// Pointer positions closer than this to an edge don't count as "in content".
    public var scrollEdgeMargin: Double = 24

    // MARK: Voice input
    public var voiceInputTrigger: VoiceInputTrigger = .searchFieldsOnly
    public var useBuiltInMicrophone: Bool = true
    public var voiceSilenceTimeout: Double = 1.5
    public var voiceReviewTimeout: Double = 4
    public var voiceDetectDelay: Double = 0.15
    /// Focus changes later than this after a HeadsUp click don't start listening.
    public var voiceClickFocusWindow: Double = 1.0

    // MARK: Pointer appearance
    public var pointerStyle: PointerStyleKind = .greenCircle
    /// nil = the style's default color.
    public var pointerColor: RGBAColor?
    public var pointerSize: PointerSize = .large
    public var pointerOpacity: Double = 1.0
    public var pointerHighContrast: Bool = true
    /// Experimental: hide the system arrow while tracking (see README).
    public var hideSystemCursor: Bool = false
    /// Floating "Top" button near the top-right corner: nodding on it scrolls the frontmost app to the top.
    public var showScrollToTopButton: Bool = true

    /// Accessibility request timeout for voice input's focused-field checks.
    public var axMessagingTimeout: Double = 0.05

    // MARK: Sound
    public var feedbackVolume: Double = 0.6
    public var feedbackMuted: Bool = false
    public var speechEnabled: Bool = true

    // MARK: Diagnostics & housekeeping
    public var telemetryRateHz: Double = 10
    public var permissionPollInterval: Double = 1.0
    public var diagnosticsInterval: Double = 1.0

    public init() {}

    public static let defaults = HeadsUpSettings()

    public var resolvedPointerColor: RGBAColor { pointerColor ?? pointerStyle.defaultColor }
}
