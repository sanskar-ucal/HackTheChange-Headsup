import Foundation

/// Every tunable number in HeadsUp. Angles are degrees, durations seconds and distances
/// points here (human-friendly for the Settings UI); components convert internally.
public struct Settings: Codable, Equatable, Sendable {
    // MARK: Pointing
    /// 0.25…1.5. At 1.0 the calibrated corners reach the screen corners; lower values
    /// need more head turn for the same pointer travel (calmer).
    public var sensitivity: Double = 0.6
    /// Backlash width while the pointer is moving.
    public var deadZoneDegrees: Double = 0.6
    /// Once still, the head must move this far before the pointer starts moving again.
    public var deadZoneStartDegrees: Double = 1.0
    /// How long without movement counts as "still" for the start threshold.
    public var deadZoneSettleTime: Double = 0.25
    /// Below this head speed precision damping applies (fine control).
    public var precisionSpeedDegPerSec: Double = 15
    /// Gain multiplier for slow movement (1 = off).
    public var precisionGain: Double = 0.5
    /// How fast the damping offset is recovered during deliberate movement (per second).
    public var precisionRecoveryPerSec: Double = 3
    /// false = map to the main display only; true = map to the union of all displays.
    public var spanAllDisplays: Bool = false

    // MARK: Rendering
    /// Critically damped spring stiffness (ω²). 5000 settles in about 80 ms.
    public var pointerSpringStiffness: Double = 5000
    /// Moves smaller than this (points) are not posted.
    public var minMoveDistance: Double = 0.5
    /// Pause/resume/recenter glide.
    public var glideDuration: Double = 0.15
    /// Gesture rollback and snap glide.
    public var rollbackGlideDuration: Double = 0.08

    // MARK: Smoothing (One Euro filter)
    public var filterMinCutoff: Double = 0.5
    public var filterBeta: Double = 0.005
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
    /// Double nod toggles in-place scroll mode. Off = single nods click with no delay.
    public var doubleNodEnabled: Bool = true
    /// Both nods must start within this window.
    public var doubleNodWindow: Double = 0.9
    /// After a nod finishes, wait this long for a second nod before clicking.
    public var doubleNodWait: Double = 0.25

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
    public var practiceEnabled: Bool = true
    public var practiceDuration: Double = 20
    /// Practice target radius as a fraction of the screen height.
    public var practiceTargetRadius: Double = 0.08

    // MARK: Scrolling
    public var edgeScrollEnabled: Bool = true
    public var horizontalEdgeScroll: Bool = false
    /// On: looking up reveals content above. Off: inverted.
    public var naturalScrolling: Bool = true
    /// Multiplier on scroll speed (slider).
    public var scrollSpeed: Double = 1.0
    /// Points per second at full tilt, before `scrollSpeed`.
    public var scrollMaxSpeed: Double = 1500
    public var scrollEngageOvershootDegrees: Double = 3
    /// Degrees past the engage point to reach full speed.
    public var scrollRampDegrees: Double = 10
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
    public var pointerStyle: PointerStyleKind = .hand
    /// nil = the style's default color.
    public var pointerColor: RGBAColor?
    public var pointerSize: PointerSize = .large
    public var pointerOpacity: Double = 1.0
    public var pointerHighContrast: Bool = true
    /// Experimental: hide the system arrow while tracking (see README).
    public var hideSystemCursor: Bool = false

    // MARK: Magnetic snapping
    public var snapEnabled: Bool = true
    public var magnetStrength: Double = 0.6
    public var snapRadius: Double = 40
    public var snapStickiness: Double = 0.5
    public var snapReleaseFactor: Double = 1.4
    public var snapReleaseSpeedDegPerSec: Double = 40
    /// Snapping only engages below this head speed.
    public var snapEngageMaxSpeedDegPerSec: Double = 20
    /// Targets larger than this fraction of the screen are containers and ignored.
    public var snapMaxTargetScreenFraction: Double = 0.4
    public var targetQueryInterval: Double = 0.15
    public var targetSearchRadius: Double = 200
    public var targetMaxElements: Int = 400
    public var axMessagingTimeout: Double = 0.05

    // MARK: Sound
    public var feedbackVolume: Double = 0.6
    public var feedbackMuted: Bool = false
    public var speechEnabled: Bool = true
    public var snapTickEnabled: Bool = true
    public var snapTickVolume: Double = 0.25

    // MARK: Diagnostics & housekeeping
    public var telemetryRateHz: Double = 10
    public var permissionPollInterval: Double = 1.0
    public var diagnosticsInterval: Double = 1.0

    public init() {}

    public static let defaults = Settings()

    public var resolvedPointerColor: RGBAColor { pointerColor ?? pointerStyle.defaultColor }
}
