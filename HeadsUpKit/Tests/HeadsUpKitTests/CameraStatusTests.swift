import XCTest
@testable import HeadsUpKit

final class CameraStatusTests: XCTestCase {
    private let all: [CameraStatus] = [
        .off, .standby, .requestingAccess, .denied, .restricted, .noCamera, .starting, .running, .failed,
    ]

    func testEveryStatusHasADistinctName() {
        let names = all.map(\.displayName)
        XCTAssertFalse(names.contains(where: \.isEmpty))
        XCTAssertEqual(Set(names).count, all.count, "Settings and the menu bar must tell them apart")
    }

    func testOnlyFailuresNeedTheUsersAttention() {
        XCTAssertEqual(all.filter(\.isProblem), [.denied, .restricted, .noCamera, .failed])
    }

    func testDominantFaceNeedsAClearWinner() {
        XCTAssertEqual(DominantFace.index(ofAreas: [0.1, 0.2]), 1, "exactly twice as large is enough")
        XCTAssertNil(DominantFace.index(ofAreas: [0.2, 0.2]))
        XCTAssertEqual(DominantFace.index(ofAreas: [0.01, 0.3, 0.05]), 1)
        XCTAssertNil(DominantFace.index(ofAreas: [0.01, 0.3, 0.2]), "the runner-up decides, not the smallest")
        XCTAssertEqual(DominantFace.index(ofAreas: [0.32, 0.1], minimumRatio: 3), 0)
        XCTAssertNil(DominantFace.index(ofAreas: [0.3, 0.15], minimumRatio: 3))
    }
}
