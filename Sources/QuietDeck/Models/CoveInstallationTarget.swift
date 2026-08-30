import Foundation

enum CoveInstallationTarget {
    static let canonicalURL = URL(fileURLWithPath: "/Applications/Cove.app", isDirectory: true)

    static func preferred(
        currentBundleURL: URL,
        canonicalBundleIdentifier: String?,
        expectedBundleIdentifier: String
    ) -> URL {
        if currentBundleURL.standardizedFileURL == canonicalURL.standardizedFileURL {
            return currentBundleURL
        }
        if canonicalBundleIdentifier == expectedBundleIdentifier {
            return canonicalURL
        }
        return currentBundleURL
    }
}
