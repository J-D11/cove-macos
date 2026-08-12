import XCTest
@testable import QuietDeck

final class SpotifyNowPlayingParserTests: XCTestCase {
    func testMapsSpotifyTrackMetadata() {
        let metadata = SpotifyNowPlayingParser.metadata(from: [
            "Midnight City",
            "M83",
            "Hurry Up, We're Dreaming",
            "https://i.scdn.co/image/cover",
            "spotify:track:abc123",
            "playing"
        ])

        XCTAssertEqual(metadata?.title, "Midnight City")
        XCTAssertEqual(metadata?.artist, "M83")
        XCTAssertEqual(metadata?.album, "Hurry Up, We're Dreaming")
        XCTAssertEqual(metadata?.artworkURL?.host, "i.scdn.co")
        XCTAssertEqual(metadata?.trackURL?.scheme, "spotify")
        XCTAssertEqual(metadata?.isPlaying, true)
    }

    func testMapsPausedSpotifyTrack() {
        let metadata = SpotifyNowPlayingParser.metadata(from: [
            "Chapter One", "Narrator", "Book", "", "", "paused"
        ])

        XCTAssertEqual(metadata?.isPlaying, false)
        XCTAssertNil(metadata?.artworkURL)
        XCTAssertNil(metadata?.trackURL)
    }

    func testRejectsIncompleteOrUnsafeMetadata() {
        XCTAssertNil(SpotifyNowPlayingParser.metadata(from: ["Title"]))

        let metadata = SpotifyNowPlayingParser.metadata(from: [
            "Title", "Artist", "Album", "file:///tmp/cover.png", "javascript:alert(1)", "playing"
        ])
        XCTAssertNil(metadata?.artworkURL)
        XCTAssertNil(metadata?.trackURL)
    }
}
