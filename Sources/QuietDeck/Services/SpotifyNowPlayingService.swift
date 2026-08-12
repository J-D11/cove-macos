import AppKit
import Foundation
import OSLog

struct SpotifyNowPlayingMetadata: Equatable, Sendable {
    let title: String
    let artist: String?
    let album: String?
    let artworkURL: URL?
    let trackURL: URL?
    let isPlaying: Bool
}

enum SpotifyNowPlayingParser {
    static func metadata(from values: [String]) -> SpotifyNowPlayingMetadata? {
        guard values.count >= 6 else { return nil }

        let title = cleaned(values[0])
        guard let title else { return nil }

        return SpotifyNowPlayingMetadata(
            title: title,
            artist: cleaned(values[1]),
            album: cleaned(values[2]),
            artworkURL: validatedURL(values[3], allowedSchemes: ["https"]),
            trackURL: validatedURL(values[4], allowedSchemes: ["spotify", "https"]),
            isPlaying: values[5].localizedCaseInsensitiveContains("playing")
        )
    }

    private static func cleaned(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private static func validatedURL(_ value: String, allowedSchemes: Set<String>) -> URL? {
        guard let value = cleaned(value),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            return nil
        }
        return url
    }
}

@MainActor
final class SpotifyNowPlayingService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "SpotifyNowPlaying"
    )
    private let artworkCache = NSCache<NSURL, NSImage>()
    private var artworkTask: URLSessionDataTask?
    private var activeArtworkURL: URL?
    private var pendingArtworkCompletions: [(NSImage?) -> Void] = []

    func fetch(completion: @escaping (NowPlayingItem?) -> Void) {
        guard isSpotifyRunning else {
            completion(nil)
            return
        }

        Task { [weak self] in
            let values = await Task.detached(priority: .utility) {
                Self.readCurrentTrack()
            }.value
            guard let self,
                  let metadata = SpotifyNowPlayingParser.metadata(from: values) else {
                completion(nil)
                return
            }

            self.resolveArtwork(for: metadata) { artwork in
                completion(
                    NowPlayingItem(
                        title: metadata.title,
                        artist: metadata.artist,
                        album: metadata.album,
                        artwork: artwork,
                        source: .spotify,
                        isPlaying: metadata.isPlaying,
                        externalURL: metadata.trackURL
                    )
                )
            }
        }
    }

    func perform(_ command: NowPlayingCommand) {
        guard isSpotifyRunning else { return }
        let source: String
        switch command {
        case .previous:
            source = "tell application id \"com.spotify.client\" to previous track"
        case .togglePlayback:
            source = "tell application id \"com.spotify.client\" to playpause"
        case .next:
            source = "tell application id \"com.spotify.client\" to next track"
        }

        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    private var isSpotifyRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.spotify.client"
        ).isEmpty
    }

    private func resolveArtwork(
        for metadata: SpotifyNowPlayingMetadata,
        completion: @escaping (NSImage?) -> Void
    ) {
        guard let url = metadata.artworkURL else {
            cancelPendingArtworkRequest()
            completion(nil)
            return
        }
        if let cached = artworkCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        if activeArtworkURL == url, artworkTask != nil {
            pendingArtworkCompletions.append(completion)
            return
        }

        cancelPendingArtworkRequest()
        activeArtworkURL = url
        pendingArtworkCompletions = [completion]

        artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            let image = data.flatMap(NSImage.init(data:))
            Task { @MainActor in
                guard let self, self.activeArtworkURL == url else { return }
                if let image {
                    self.artworkCache.setObject(image, forKey: url as NSURL)
                } else if let error {
                    self.logger.debug("Spotify artwork unavailable error=\(error.localizedDescription, privacy: .public)")
                }
                let completions = self.pendingArtworkCompletions
                self.pendingArtworkCompletions = []
                self.activeArtworkURL = nil
                self.artworkTask = nil
                completions.forEach { $0(image) }
            }
        }
        artworkTask?.resume()
    }

    private func cancelPendingArtworkRequest() {
        artworkTask?.cancel()
        artworkTask = nil
        activeArtworkURL = nil
        let completions = pendingArtworkCompletions
        pendingArtworkCompletions = []
        completions.forEach { $0(nil) }
    }

    nonisolated private static func readCurrentTrack() -> [String] {
        let source = """
        tell application id "com.spotify.client"
            if player state is stopped then return {}
            set activeTrack to current track
            set coverAddress to ""
            set trackAddress to ""
            try
                set coverAddress to artwork url of activeTrack
            end try
            try
                set trackAddress to spotify url of activeTrack
            end try
            return {name of activeTrack, artist of activeTrack, album of activeTrack, coverAddress, trackAddress, player state as text}
        end tell
        """

        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error),
              error == nil,
              result.numberOfItems >= 6 else {
            return []
        }

        return (1...result.numberOfItems).map { index in
            result.atIndex(index)?.stringValue ?? ""
        }
    }
}
