import AppKit
import Darwin
import Foundation

enum NowPlayingMetadataParser {
    private enum Key {
        static let title = "kMRMediaRemoteNowPlayingInfoTitle"
        static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
        static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
        static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    }

    static func item(from dictionary: NSDictionary?) -> NowPlayingItem? {
        guard let dictionary else { return nil }

        let title = cleanedString(dictionary[Key.title])
        let artist = cleanedString(dictionary[Key.artist])
        let album = cleanedString(dictionary[Key.album])
        let artwork = (dictionary[Key.artworkData] as? Data).flatMap(NSImage.init(data:))

        guard title != nil || artist != nil || album != nil || artwork != nil else {
            return nil
        }

        return NowPlayingItem(
            title: title ?? album ?? "Now Playing",
            artist: artist,
            album: album,
            artwork: artwork
        )
    }

    private static func cleanedString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

@MainActor
final class NowPlayingService {
    private typealias Callback = @convention(block) (CFDictionary?) -> Void
    private typealias GetNowPlayingInfo = @convention(c) (DispatchQueue, AnyObject) -> Void

    private let getNowPlayingInfo: GetNowPlayingInfo?
    private let spotifyService = SpotifyNowPlayingService()

    init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(frameworkPath, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            getNowPlayingInfo = nil
            return
        }
        getNowPlayingInfo = unsafeBitCast(symbol, to: GetNowPlayingInfo.self)
    }

    func fetch(completion: @escaping (NowPlayingItem?) -> Void) {
        spotifyService.fetch { [weak self] item in
            guard let self else { return }
            if let item {
                completion(item)
            } else {
                self.fetchSystemNowPlaying(completion: completion)
            }
        }
    }

    func perform(_ command: NowPlayingCommand, for item: NowPlayingItem) {
        guard item.source == .spotify else { return }
        spotifyService.perform(command)
    }

    private func fetchSystemNowPlaying(completion: @escaping (NowPlayingItem?) -> Void) {
        guard let getNowPlayingInfo else {
            completion(nil)
            return
        }

        let callback: Callback = { dictionary in
            let item = NowPlayingMetadataParser.item(from: dictionary as NSDictionary?)
            DispatchQueue.main.async {
                completion(item)
            }
        }
        getNowPlayingInfo(
            DispatchQueue.global(qos: .utility),
            unsafeBitCast(callback, to: AnyObject.self)
        )
    }
}
