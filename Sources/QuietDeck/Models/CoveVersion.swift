import Foundation

struct CoveVersion: Comparable, Equatable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: CoveVersion, rhs: CoveVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    init?(_ rawValue: String) {
        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "v" || trimmed.first == "V" {
            trimmed.removeFirst()
        }
        let numericPart = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
        let components = numericPart.split(separator: ".")
        guard (2...3).contains(components.count),
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return nil
        }

        let patch = components.count == 3 ? Int(components[2]) : 0
        guard let patch else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }
}
