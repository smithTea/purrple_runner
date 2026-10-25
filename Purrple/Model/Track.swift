import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: UUID
    /// Path relative to the app's Documents folder. The container path changes
    /// between installs, so absolute paths are never stored.
    var relativePath: String
    var title: String
    var artist: String
    var album: String
    var albumArtist: String?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval
    var hasArtwork: Bool
    var dateAdded: Date

    var fileExtension: String { (relativePath as NSString).pathExtension.uppercased() }

    var albumID: String {
        "\((albumArtist ?? artist).lowercased())\u{1F}\(album.lowercased())"
    }
}

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]

    var artworkTrack: Track? { tracks.first(where: \.hasArtwork) ?? tracks.first }
    var dateAdded: Date { tracks.map(\.dateAdded).max() ?? .distantPast }
}

struct Artist: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let tracks: [Track]

    var artworkTrack: Track? { tracks.first(where: \.hasArtwork) ?? tracks.first }
}

extension Array where Element == Track {
    /// Disc, then track number, then title.
    func sortedForAlbum() -> [Track] {
        sorted {
            ($0.discNumber ?? 1, $0.trackNumber ?? Int.max, $0.title)
                < ($1.discNumber ?? 1, $1.trackNumber ?? Int.max, $1.title)
        }
    }
}
