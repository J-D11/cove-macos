import Foundation
import XCTest
@testable import QuietDeck

final class CoveUpdateChannelTests: XCTestCase {
    func testStableRejectsPrereleasesAndBetaAllowsThem() {
        XCTAssertFalse(CoveUpdateChannel.stable.allowsPrereleases)
        XCTAssertTrue(CoveUpdateChannel.beta.allowsPrereleases)
    }

    @MainActor
    func testBetaEndpointAcceptsPrereleaseThatStableIgnores() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateChannelURLProtocol.self]
        let service = UpdateService(bundle: .main, session: URLSession(configuration: configuration))

        let stable = try await service.checkForUpdates(channel: .stable)
        let beta = try await service.checkForUpdates(channel: .beta)

        XCTAssertNil(stable)
        XCTAssertEqual(beta?.version, CoveVersion(major: 99, minor: 0, patch: 0))
        XCTAssertEqual(beta?.assetName, "Cove-99.0.0-beta.app.zip")
    }

    @MainActor
    func testBetaFallsBackToNewestCompatibleRelease() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateChannelURLProtocol.self]
        UpdateChannelURLProtocol.includesNewerIncompatibleRelease = true
        defer { UpdateChannelURLProtocol.includesNewerIncompatibleRelease = false }
        let service = UpdateService(bundle: .main, session: URLSession(configuration: configuration))

        let beta = try await service.checkForUpdates(channel: .beta)

        XCTAssertEqual(beta?.version, CoveVersion(major: 99, minor: 0, patch: 0))
        XCTAssertEqual(beta?.assetName, "Cove-99.0.0-beta.app.zip")
    }
}

private final class UpdateChannelURLProtocol: URLProtocol {
    nonisolated(unsafe) static var includesNewerIncompatibleRelease = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let release = """
        {
          "tag_name": "v99.0.0-beta.1",
          "name": "Cove 99 Beta",
          "html_url": "https://github.com/J-D11/cove-macos/releases/tag/v99.0.0-beta.1",
          "draft": false,
          "prerelease": true,
          "assets": [
            {
              "name": "Cove-99.0.0-beta.app.zip",
              "browser_download_url": "https://github.com/J-D11/cove-macos/releases/download/v99.0.0-beta.1/Cove-99.0.0-beta.app.zip",
              "digest": null
            }
          ]
        }
        """
        let incompatibleRelease = """
        {
          "tag_name": "v100.0.0-beta.1",
          "name": "Cove 100 Beta",
          "html_url": "https://github.com/J-D11/cove-macos/releases/tag/v100.0.0-beta.1",
          "draft": false,
          "prerelease": true,
          "assets": []
        }
        """
        let betaPayload = Self.includesNewerIncompatibleRelease
            ? "[\(incompatibleRelease),\(release)]"
            : "[\(release)]"
        let payload = request.url?.path.hasSuffix("/latest") == true ? release : betaPayload
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
