import Foundation
import XCTest
@testable import QuietDeck

final class CoveInstanceArbitratorTests: XCTestCase {
    func testNewerVersionWinsEvenWhenOlderCopyIsInApplications() {
        let installed = candidate(pid: 100, version: "0.7.0", build: 19, path: "/Applications/Cove.app")
        let downloaded = candidate(pid: 200, version: "0.7.1", build: 20, path: "/tmp/Downloads/Cove.app")

        XCTAssertEqual(
            CoveInstanceArbitrator.preferred(from: [installed, downloaded]),
            downloaded
        )
    }

    func testHigherBuildWinsWhenVersionsMatch() {
        let oldBuild = candidate(pid: 100, version: "0.7.1", build: 20, path: "/Applications/Cove.app")
        let newBuild = candidate(pid: 200, version: "0.7.1", build: 21, path: "/tmp/Downloads/Cove.app")

        XCTAssertEqual(CoveInstanceArbitrator.preferred(from: [oldBuild, newBuild]), newBuild)
    }

    func testApplicationsCopyWinsWhenVersionAndBuildMatch() {
        let installed = candidate(pid: 200, version: "0.7.1", build: 20, path: "/Applications/Cove.app")
        let downloaded = candidate(pid: 100, version: "0.7.1", build: 20, path: "/tmp/Downloads/Cove.app")

        XCTAssertEqual(
            CoveInstanceArbitrator.preferred(from: [downloaded, installed]),
            installed
        )
    }

    func testOldestProcessWinsForExactDuplicates() {
        let first = candidate(pid: 100, version: "0.7.1", build: 20, path: "/Applications/Cove.app")
        let second = candidate(pid: 200, version: "0.7.1", build: 20, path: "/Applications/Cove.app")

        XCTAssertEqual(CoveInstanceArbitrator.preferred(from: [second, first]), first)
    }

    private func candidate(
        pid: pid_t,
        version: String,
        build: Int,
        path: String
    ) -> CoveInstanceCandidate {
        CoveInstanceCandidate(
            processIdentifier: pid,
            version: CoveVersion(version)!,
            build: build,
            bundleURL: URL(fileURLWithPath: path)
        )
    }
}
