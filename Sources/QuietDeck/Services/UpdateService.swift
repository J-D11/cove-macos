import AppKit
import CryptoKit
import Foundation
import OSLog

struct CoveUpdate: Equatable {
    let version: CoveVersion
    let releaseName: String
    let releaseURL: URL
    let assetName: String
    let downloadURL: URL
    let expectedSHA256: String?
}

enum UpdateServiceError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case releaseUnavailable
    case noCompatibleAsset
    case invalidDownloadURL
    case checksumMismatch
    case invalidApplication
    case updateNotNewer
    case commandFailed(String, String?)
    case installLocationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid update response."
        case .httpError(let statusCode):
            return "GitHub returned HTTP status \(statusCode) while checking for the update."
        case .releaseUnavailable:
            return "No stable Cove release is available yet."
        case .noCompatibleAsset:
            return "The latest Cove release does not contain a compatible app archive."
        case .invalidDownloadURL:
            return "The release download URL is not trusted."
        case .checksumMismatch:
            return "The downloaded update failed its integrity check."
        case .invalidApplication:
            return "The downloaded update is not a valid Cove application."
        case .updateNotNewer:
            return "The downloaded version is not newer than this copy of Cove."
        case .commandFailed(let command, let details):
            if let details, !details.isEmpty {
                return "Cove could not validate the downloaded app with \(command): \(details)"
            }
            return "Cove could not validate the downloaded app with \(command)."
        case .installLocationUnavailable:
            return "Cove cannot replace the current app at its installed location."
        }
    }
}

@MainActor
final class UpdateService {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case draft
            case prerelease
            case assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case digest
        }
    }

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/J-D11/cove-macos/releases/latest"
    )!
    private static let releasesURL = URL(
        string: "https://api.github.com/repos/J-D11/cove-macos/releases?per_page=20"
    )!
    private static let trustedDownloadHosts = Set([
        "github.com",
        "objects.githubusercontent.com",
        "release-assets.githubusercontent.com"
    ])

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "Updates"
    )
    private let currentVersion: CoveVersion
    private let currentBundleURL: URL
    private let session: URLSession

    init(
        bundle: Bundle = .main,
        session: URLSession = .shared
    ) {
        currentVersion = CoveVersion(
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        ) ?? CoveVersion(major: 0, minor: 0, patch: 0)
        currentBundleURL = bundle.bundleURL
        self.session = session
    }

    var versionDescription: String {
        currentVersion.description
    }

    func checkForUpdates(channel: CoveUpdateChannel = .stable) async throws -> CoveUpdate? {
        var request = URLRequest(
            url: channel == .stable ? Self.latestReleaseURL : Self.releasesURL
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Cove/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw UpdateServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw UpdateServiceError.httpError(response.statusCode)
        }

        let releases: [GitHubRelease]
        do {
            if channel == .stable {
                releases = [try JSONDecoder().decode(GitHubRelease.self, from: data)]
            } else {
                releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
            }
        } catch {
            logger.error("Could not decode GitHub release metadata: \(error.localizedDescription, privacy: .public)")
            throw UpdateServiceError.invalidResponse
        }

        let eligibleReleases = releases.compactMap { release -> (GitHubRelease, CoveVersion)? in
            guard !release.draft,
                  channel.allowsPrereleases || !release.prerelease,
                  let version = CoveVersion(release.tagName),
                  version > currentVersion else {
                return nil
            }
            return (release, version)
        }
        guard !eligibleReleases.isEmpty else {
            if releases.contains(where: { !$0.draft }) {
                return nil
            }
            throw UpdateServiceError.releaseUnavailable
        }

        let compatibleRelease = eligibleReleases
            .sorted { $0.1 > $1.1 }
            .compactMap { release, version -> (GitHubRelease, CoveVersion, GitHubAsset)? in
                guard let asset = release.assets.first(where: {
                    isSupportedAsset($0) && isTrustedDownloadURL($0.browserDownloadURL)
                }) else {
                    return nil
                }
                return (release, version, asset)
            }
            .first
        guard let (release, version, asset) = compatibleRelease else {
            throw UpdateServiceError.noCompatibleAsset
        }

        return CoveUpdate(
            version: version,
            releaseName: release.name ?? "Cove \(version)",
            releaseURL: release.htmlURL,
            assetName: asset.name,
            downloadURL: asset.browserDownloadURL,
            expectedSHA256: normalizedDigest(asset.digest)
        )
    }

    func prepareInstallation(
        for update: CoveUpdate,
        onProgress: @escaping (Double?) -> Void = { _ in }
    ) async throws {
        guard update.version > currentVersion else {
            throw UpdateServiceError.updateNotNewer
        }
        guard currentBundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
            throw UpdateServiceError.installLocationUnavailable
        }

        let stagingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoveUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

        do {
            let archiveURL = stagingRoot.appendingPathComponent(update.assetName)
            try await download(update.downloadURL, to: archiveURL, onProgress: onProgress)
            try verifyChecksum(of: archiveURL, expectedSHA256: update.expectedSHA256)

            try run(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, stagingRoot.path]
            )

            guard let appURL = applicationURL(in: stagingRoot) else {
                throw UpdateServiceError.invalidApplication
            }
            try validateDownloadedApplication(appURL, expectedVersion: update.version)
            try launchInstaller(
                sourceURL: appURL,
                stagingRoot: stagingRoot,
                targetURL: currentBundleURL,
                processIdentifier: ProcessInfo.processInfo.processIdentifier
            )
        } catch {
            try? FileManager.default.removeItem(at: stagingRoot)
            throw error
        }
    }

    private func download(
        _ url: URL,
        to destination: URL,
        onProgress: @escaping (Double?) -> Void
    ) async throws {
        guard isTrustedDownloadURL(url) else {
            throw UpdateServiceError.invalidDownloadURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Cove/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw UpdateServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw UpdateServiceError.httpError(response.statusCode)
        }

        let expectedLength = response.expectedContentLength > 0
            ? response.expectedContentLength
            : nil
        var receivedLength: Int64 = 0
        var lastReportedProgress = -1.0
        var data = Data()
        if let expectedLength {
            data.reserveCapacity(Int(expectedLength))
        } else {
            onProgress(nil)
        }

        for try await byte in bytes {
            data.append(byte)
            receivedLength += 1
            if let expectedLength {
                let progress = min(Double(receivedLength) / Double(expectedLength), 1)
                if progress - lastReportedProgress >= 0.01 || progress == 1 {
                    lastReportedProgress = progress
                    onProgress(progress)
                }
            }
        }

        try data.write(to: destination, options: .atomic)
        onProgress(1)
    }

    private func verifyChecksum(of archiveURL: URL, expectedSHA256: String?) throws {
        guard let expectedSHA256 else { return }
        let data = try Data(contentsOf: archiveURL)
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        guard digest.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            throw UpdateServiceError.checksumMismatch
        }
    }

    private func validateDownloadedApplication(
        _ appURL: URL,
        expectedVersion: CoveVersion
    ) throws {
        guard let bundle = Bundle(url: appURL),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let versionString = bundle.object(
                  forInfoDictionaryKey: "CFBundleShortVersionString"
              ) as? String,
              let version = CoveVersion(versionString),
              version == expectedVersion,
              version > currentVersion else {
            throw UpdateServiceError.invalidApplication
        }

        try run(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", appURL.path]
        )
        try run(
            executable: "/usr/sbin/spctl",
            arguments: ["--assess", "--type", "execute", "--verbose=2", appURL.path]
        )
    }

    private func launchInstaller(
        sourceURL: URL,
        stagingRoot: URL,
        targetURL: URL,
        processIdentifier: pid_t
    ) throws {
        let helperURL = stagingRoot.appendingPathComponent("install-cove-update.sh")
        let script = """
        #!/bin/sh
        set -eu

        SOURCE=\(shellQuote(sourceURL.path))
        STAGING=\(shellQuote(stagingRoot.path))
        TARGET=\(shellQuote(targetURL.path))
        TARGET_PARENT=\(shellQuote(targetURL.deletingLastPathComponent().path))
        NEW_TARGET="$TARGET.cove-update-new.$$"
        BACKUP="$TARGET.cove-update-backup.$$"
        PID=\(processIdentifier)

        for _ in $(/usr/bin/seq 1 200); do
            if /bin/kill -0 "$PID" 2>/dev/null; then
                /bin/sleep 0.25
            else
                break
            fi
        done

        if [ ! -w "$TARGET_PARENT" ]; then
            /usr/bin/osascript - "$SOURCE" "$TARGET" "$STAGING" <<'APPLESCRIPT'
        on run argv
            set sourcePath to quoted form of (item 1 of argv)
            set targetPath to quoted form of (item 2 of argv)
            set stagingPath to quoted form of (item 3 of argv)
            set command to "/usr/bin/xattr -cr " & sourcePath & " && /bin/rm -rf " & targetPath & " && /usr/bin/ditto --norsrc " & sourcePath & " " & targetPath
            do shell script command with administrator privileges
            do shell script "/usr/bin/open -n " & targetPath
            do shell script "/bin/rm -rf " & stagingPath
        end run
        APPLESCRIPT
            exit 0
        fi

        /usr/bin/xattr -cr "$SOURCE"
        /bin/rm -rf "$NEW_TARGET" "$BACKUP"
        /usr/bin/ditto --norsrc "$SOURCE" "$NEW_TARGET"
        /bin/mv "$TARGET" "$BACKUP"
        if ! /bin/mv "$NEW_TARGET" "$TARGET"; then
            /bin/mv "$BACKUP" "$TARGET"
            exit 1
        fi
        /bin/rm -rf "$BACKUP"
        /usr/bin/open -n "$TARGET"
        /bin/rm -rf "$STAGING"
        """

        try script.write(to: helperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: helperURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [helperURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private func applicationURL(in stagingRoot: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: stagingRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.pathExtension == "app" {
            return url
        }
        return nil
    }

    private func run(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let details = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateServiceError.commandFailed(
                URL(fileURLWithPath: executable).lastPathComponent,
                details
            )
        }
    }

    private func isSupportedAsset(_ asset: GitHubAsset) -> Bool {
        let name = asset.name.lowercased()
        return name.hasSuffix(".app.zip")
            && (name.contains("cove") || name.contains("quietdeck"))
    }

    private func isTrustedDownloadURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host.map { Self.trustedDownloadHosts.contains($0.lowercased()) } == true
    }

    private func normalizedDigest(_ digest: String?) -> String? {
        guard let digest else { return nil }
        let value = digest.lowercased()
        if value.hasPrefix("sha256:") {
            return String(value.dropFirst("sha256:".count))
        }
        return value.count == 64 ? value : nil
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
