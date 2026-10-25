import Foundation
import SFBAudioEngine
import UIKit

/// The music library: every audio file inside the app's Documents folder.
///
/// Files get there either through the in-app importer (copied into
/// Documents/Music) or by dropping them into "On My iPhone › Purrple" in the
/// Files app / Finder. `rescan()` picks up additions and removals.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var likedIDs: Set<UUID> = []
    @Published private(set) var isScanning = false
    @Published var lastError: String?

    nonisolated static let audioExtensions: Set<String> = [
        "mp3", "flac", "ogg", "oga", "opus", "m4a", "aac", "wav", "aif", "aiff", "caf", "wv", "ape", "mpc",
    ]

    let documentsURL: URL
    let musicURL: URL
    private let supportURL: URL
    private var libraryFileURL: URL { supportURL.appendingPathComponent("library.json") }

    private struct Persisted: Codable {
        var tracks: [Track]
        var liked: [UUID]
    }

    init() {
        let fm = FileManager.default
        documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        musicURL = documentsURL.appendingPathComponent("Music", isDirectory: true)
        supportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Purrple", isDirectory: true)
        try? fm.createDirectory(at: musicURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: supportURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: Lookup

    func url(for track: Track) -> URL {
        documentsURL.appendingPathComponent(track.relativePath)
    }

    func isLiked(_ track: Track) -> Bool { likedIDs.contains(track.id) }

    var likedTracks: [Track] {
        tracks.filter { likedIDs.contains($0.id) }.sorted { $0.dateAdded > $1.dateAdded }
    }

    var recentlyAdded: [Track] {
        tracks.sorted { $0.dateAdded > $1.dateAdded }
    }

    var albums: [Album] {
        Dictionary(grouping: tracks, by: \.albumID)
            .map { id, tracks in
                let first = tracks[0]
                return Album(id: id, title: first.album, artist: first.albumArtist ?? first.artist,
                             tracks: tracks.sortedForAlbum())
            }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    var artists: [Artist] {
        Dictionary(grouping: tracks, by: { $0.albumArtist ?? $0.artist })
            .map { Artist(name: $0.key, tracks: $0.value.sorted { ($0.album, $0.trackNumber ?? 0) < ($1.album, $1.trackNumber ?? 0) }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Mutations

    func toggleLike(_ track: Track) {
        if likedIDs.contains(track.id) {
            likedIDs.remove(track.id)
        } else {
            likedIDs.insert(track.id)
        }
        save()
    }

    func delete(_ track: Track) {
        try? FileManager.default.removeItem(at: url(for: track))
        ArtworkStore.shared.remove(track)
        tracks.removeAll { $0.id == track.id }
        likedIDs.remove(track.id)
        save()
    }

    /// Copies picked files (or whole folders) into Documents/Music, then rescans.
    func importItems(_ urls: [URL]) async {
        let destination = musicURL
        let failures = await Task.detached(priority: .userInitiated) { () -> [String] in
            var failures: [String] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    try Self.copyAudio(from: url, into: destination)
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            return failures
        }.value
        if !failures.isEmpty {
            lastError = "Couldn't import:\n" + failures.joined(separator: "\n")
        }
        await rescan()
    }

    /// Syncs the library with what is on disk.
    func rescan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let documents = documentsURL
        let onDisk = await Task.detached(priority: .utility) { Self.audioFiles(under: documents) }.value
        let onDiskSet = Set(onDisk)

        let removed = tracks.filter { !onDiskSet.contains($0.relativePath) }
        for track in removed { ArtworkStore.shared.remove(track) }
        var updated = tracks.filter { onDiskSet.contains($0.relativePath) }

        let known = Set(updated.map(\.relativePath))
        let newPaths = onDisk.filter { !known.contains($0) }
        if !newPaths.isEmpty {
            let artworkDir = ArtworkStore.shared.directory
            let added = await Task.detached(priority: .utility) {
                newPaths.map { Self.readTrack(relativePath: $0, documents: documents, artworkDir: artworkDir) }
            }.value
            updated.append(contentsOf: added)
        }

        if !removed.isEmpty || !newPaths.isEmpty {
            tracks = updated
            likedIDs.formIntersection(Set(updated.map(\.id)))
            save()
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: libraryFileURL),
              let persisted = try? JSONDecoder().decode(Persisted.self, from: data)
        else { return }
        tracks = persisted.tracks
        likedIDs = Set(persisted.liked)
    }

    private func save() {
        let persisted = Persisted(tracks: tracks, liked: Array(likedIDs))
        do {
            try JSONEncoder().encode(persisted).write(to: libraryFileURL, options: .atomic)
        } catch {
            lastError = "Couldn't save library: \(error.localizedDescription)"
        }
    }

    // MARK: File work (off the main actor)

    nonisolated private static func isAudio(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated private static func audioFiles(under root: URL) -> [String] {
        let rootPath = root.standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        var paths: [String] = []
        for case let url as URL in enumerator where isAudio(url) {
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(rootPath) else { continue }
            paths.append(String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }
        return paths
    }

    nonisolated private static func copyAudio(from source: URL, into destination: URL) throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDirectory) else { return }

        if isDirectory.boolValue {
            let folder = uniqueURL(destination.appendingPathComponent(source.lastPathComponent, isDirectory: true))
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for child in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                try copyAudio(from: child, into: folder)
            }
        } else if isAudio(source) {
            try fm.copyItem(at: source, to: uniqueURL(destination.appendingPathComponent(source.lastPathComponent)))
        }
    }

    nonisolated private static func uniqueURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parent = url.deletingLastPathComponent()
        var n = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            let candidate = parent.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    nonisolated private static func readTrack(relativePath: String, documents: URL, artworkDir: URL) -> Track {
        let url = documents.appendingPathComponent(relativePath)
        var track = Track(
            id: UUID(), relativePath: relativePath,
            title: url.deletingPathExtension().lastPathComponent,
            artist: "Unknown Artist", album: "Unknown Album", albumArtist: nil,
            trackNumber: nil, discNumber: nil, duration: 0, hasArtwork: false,
            dateAdded: Date()
        )
        guard let file = try? AudioFile(readingPropertiesAndMetadataFrom: url) else { return track }

        let metadata = file.metadata
        if let title = metadata.title?.trimmed { track.title = title }
        if let artist = metadata.artist?.trimmed { track.artist = artist }
        if let album = metadata.albumTitle?.trimmed { track.album = album }
        track.albumArtist = metadata.albumArtist?.trimmed
        track.trackNumber = metadata.trackNumber
        track.discNumber = metadata.discNumber
        track.duration = file.properties.duration ?? 0

        let pictures = metadata.attachedPictures
        if let picture = pictures.first(where: { $0.type == .frontCover }) ?? pictures.first {
            track.hasArtwork = ArtworkStore.saveArtwork(picture.imageData, for: track.id, in: artworkDir)
        }
        return track
    }
}

private extension String {
    /// The string without surrounding whitespace, or nil when that leaves nothing.
    var trimmed: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
