import XCTest
@testable import QuietDeck

final class CoveRuntimePolicyTests: XCTestCase {
    func testLiveBuildAllowsPersistentSystemIntegrations() {
        let policy = CoveRuntimePolicy(isPreviewMode: false)

        XCTAssertTrue(policy.allowsPersistentChanges)
        XCTAssertTrue(policy.installsSystemIntegrations)
        XCTAssertTrue(policy.arbitratesRunningInstances)
    }

    func testPreviewBuildIsIsolatedFromPersistentSystemIntegrations() {
        let policy = CoveRuntimePolicy(isPreviewMode: true)

        XCTAssertFalse(policy.allowsPersistentChanges)
        XCTAssertFalse(policy.installsSystemIntegrations)
        XCTAssertFalse(policy.arbitratesRunningInstances)
    }
}
