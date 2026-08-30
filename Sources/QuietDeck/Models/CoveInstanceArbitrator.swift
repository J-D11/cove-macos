import Foundation

struct CoveInstanceCandidate: Equatable {
    let processIdentifier: pid_t
    let version: CoveVersion
    let build: Int
    let bundleURL: URL

    var isCanonicalInstallation: Bool {
        bundleURL.standardizedFileURL.path == "/Applications/Cove.app"
    }
}

enum CoveInstanceArbitrator {
    static func preferred(from candidates: [CoveInstanceCandidate]) -> CoveInstanceCandidate? {
        candidates.max { lhs, rhs in
            if lhs.version != rhs.version {
                return lhs.version < rhs.version
            }
            if lhs.build != rhs.build {
                return lhs.build < rhs.build
            }
            if lhs.isCanonicalInstallation != rhs.isCanonicalInstallation {
                return !lhs.isCanonicalInstallation
            }
            return lhs.processIdentifier > rhs.processIdentifier
        }
    }

    static func candidate(
        processIdentifier: pid_t,
        bundleURL: URL
    ) -> CoveInstanceCandidate? {
        guard let bundle = Bundle(url: bundleURL),
              let versionString = bundle.object(
                  forInfoDictionaryKey: "CFBundleShortVersionString"
              ) as? String,
              let version = CoveVersion(versionString) else {
            return nil
        }

        let buildString = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return CoveInstanceCandidate(
            processIdentifier: processIdentifier,
            version: version,
            build: Int(buildString ?? "") ?? 0,
            bundleURL: bundleURL
        )
    }
}
