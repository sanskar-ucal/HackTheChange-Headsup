import XCTest
@testable import HeadsUpKit

/// The camera must be off whenever blinks can't be used, for privacy and power.
@MainActor
final class BlinkCameraStateTests: XCTestCase {
    func testCameraRunsOnlyWhileHeadsUpIsInUse() {
        let all: [AppState] = [
            .needsPermissions, .waitingForHeadphones, .calibrating(.center), .practicing, .awaitingRecenter,
            .tracking, .scrollMode, .listening, .voiceReview, .paused,
        ]
        XCTAssertEqual(all.filter(AppCoordinator.cameraRuns(in:)),
                       [.practicing, .awaitingRecenter, .tracking, .scrollMode, .listening, .voiceReview])
    }

    func testCameraNeverRunsWhereActionsAreBlockedExceptToPrepareTracking() {
        // Outside the action states the camera only runs to learn the open-eye baseline
        // just before tracking (recenter, practice).
        let warmUp: [AppState] = [.practicing, .awaitingRecenter]
        for state in [AppState.practicing, .awaitingRecenter, .paused, .needsPermissions] where !state.allowsActions {
            XCTAssertEqual(AppCoordinator.cameraRuns(in: state), warmUp.contains(state), "\(state)")
        }
    }
}
