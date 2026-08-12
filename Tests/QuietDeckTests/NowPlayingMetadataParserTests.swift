import AppKit
import XCTest
@testable import QuietDeck

final class NowPlayingMetadataParserTests: XCTestCase {
    func testMapsMediaRemoteMetadata() {
        let item = NowPlayingMetadataParser.item(
            from: [
                "kMRMediaRemoteNowPlayingInfoTitle": "Chapter One",
                "kMRMediaRemoteNowPlayingInfoArtist": "Narrator",
                "kMRMediaRemoteNowPlayingInfoAlbum": "The Book"
            ] as NSDictionary
        )

        XCTAssertEqual(item?.title, "Chapter One")
        XCTAssertEqual(item?.artist, "Narrator")
        XCTAssertEqual(item?.album, "The Book")
        XCTAssertEqual(item?.helpText, "Chapter One · Narrator · The Book")
    }

    func testRejectsEmptyMetadata() {
        XCTAssertNil(NowPlayingMetadataParser.item(from: [:]))
    }

    func testDecodesArtworkData() {
        let source = NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: nil
        )
        let data = source?.tiffRepresentation

        let item = NowPlayingMetadataParser.item(
            from: [
                "kMRMediaRemoteNowPlayingInfoTitle": "A Song",
                "kMRMediaRemoteNowPlayingInfoArtworkData": data as Any
            ] as NSDictionary
        )

        XCTAssertNotNil(item?.artwork)
    }
}
