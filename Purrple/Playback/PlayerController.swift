import AVFoundation
import MediaPlayer
import SFBAudioEngine
import SwiftUI

/// Owns the play queue and drives SFBAudioEngine, which decodes MP3, FLAC,
/// Ogg Vorbis/Opus and everything Core Audio handles.
@MainActor
final class PlayerController: NSObject, ObservableObject {
    enum RepeatMode {
        case off, all, one

        var next: RepeatMode {
            switch self {
            case .off: return .all
            case .all: return .one
            case .one: return .off
            }
        }
    }

    @Published private(set) var queue: [Track] = []
    @Published private(set) var index: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var shuffle = false
    @Published var repeatMode: RepeatMode = .off
    @Published var errorMessage: String?
    /// Name of what the queue was started from, e.g. an album title.
    @Published private(set) var context: String = ""

    var current: Track? {
        guard let index, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    var progress: Double {
        duration > 0 ? min(1, currentTime / duration) : 0
    }

    private let player = AudioPlayer()
    private let library: LibraryStore
    private var unshuffledQueue: [Track] = []
    private var ticker: Timer?

    init(library: LibraryStore) {
        self.library = library
        super.init()
        player.delegate = self
        configureAudioSession()
        configureRemoteCommands()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: Queue control

    func play(_ tracks: [Track], startAt start: Int = 0, context: String) {
        guard tracks.indices.contains(start) else { return }
        self.context = context
        unshuffledQueue = tracks
        if shuffle {
            var rest = tracks
            let first = rest.remove(at: start)
            queue = [first] + rest.shuffled()
            index = 0
        } else {
            queue = tracks
            index = start
        }
        loadCurrent()
    }

    func shufflePlay(_ tracks: [Track], context: String) {
        guard !tracks.isEmpty else { return }
        shuffle = true
        play(tracks, startAt: Int.random(in: tracks.indices), context: context)
    }

    func togglePlayPause() {
        guard current != nil else { return }
        if player.isStopped {
            loadCurrent()
        } else if player.isPlaying {
            player.pause()
        } else {
            activateSession()
            player.resume()
        }
        syncState()
    }

    func next() {
        advance(userInitiated: true)
    }

    func previous() {
        guard let index else { return }
        if currentTime > 3 || index == 0 {
            seek(to: 0)
        } else {
            self.index = index - 1
            loadCurrent()
        }
    }

    func seek(to time: TimeInterval) {
        guard current != nil else { return }
        if player.isStopped { loadCurrent(autoplay: false) }
        if player.seek(time: max(0, min(time, duration))) {
            currentTime = time
        }
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        shuffle.toggle()
        guard let current else { return }
        if shuffle {
            var rest = queue
            rest.removeAll { $0.id == current.id }
            queue = [current] + rest.shuffled()
            index = 0
        } else {
            queue = unshuffledQueue
            index = queue.firstIndex(where: { $0.id == current.id }) ?? 0
        }
    }

    func cycleRepeat() {
        repeatMode = repeatMode.next
    }

    func playQueueItem(at position: Int) {
        guard queue.indices.contains(position) else { return }
        index = position
        loadCurrent()
    }

    /// Drops a deleted track from the queue, stopping if it was playing.
    func remove(_ track: Track) {
        unshuffledQueue.removeAll { $0.id == track.id }
        guard let position = queue.firstIndex(where: { $0.id == track.id }) else { return }
        let wasCurrent = position == index
        queue.remove(at: position)
        if wasCurrent {
            player.stop()
            index = queue.isEmpty ? nil : min(position, queue.count - 1)
            currentTime = 0
            syncState()
        } else if let index, position < index {
            self.index = index - 1
        }
    }

    // MARK: Internals

    private func advance(userInitiated: Bool) {
        guard let index else { return }
        if !userInitiated && repeatMode == .one {
            loadCurrent()
        } else if index + 1 < queue.count {
            self.index = index + 1
            loadCurrent()
        } else if repeatMode != .off {
            self.index = 0
            loadCurrent()
        } else {
            // End of queue: rewind to the start of the last track, paused.
            player.stop()
            currentTime = 0
            syncState()
        }
    }

    private func loadCurrent(autoplay: Bool = true) {
        guard let track = current else { return }
        let url = library.url(for: track)
        duration = track.duration
        currentTime = 0
        do {
            activateSession()
            if autoplay {
                try player.play(url)
            } else {
                try player.enqueue(url, immediate: true)
            }
        } catch {
            errorMessage = "Can't play \(track.title): \(error.localizedDescription)"
            player.stop()
        }
        syncState()
    }

    private func tick() {
        guard current != nil else { return }
        if let time = player.time {
            if let now = time.current { currentTime = now }
            if let total = time.total, total > 0 { duration = total }
        }
        if isPlaying != player.isPlaying { syncState() }
    }

    private func syncState() {
        isPlaying = player.isPlaying
        updateNowPlayingInfo()
    }

    // MARK: System integration

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .success }
            self.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .success }
            self.togglePlayPause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        let center = MPNowPlayingInfoCenter.default()
        guard let track = current else {
            center.nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let image = ArtworkStore.shared.image(for: track) {
            info[MPMediaItemPropertyArtwork] = Self.makeArtwork(image)
        }
        center.nowPlayingInfo = info
    }

    /// Built outside the main actor: MediaPlayer calls the handler on a
    /// background queue, and a main-actor closure would trap there.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}

extension PlayerController: AudioPlayer.Delegate {
    // Called on SFBAudioEngine's internal queue once the current file has
    // finished rendering and nothing else is queued.
    nonisolated func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) {
        Task { @MainActor in self.advance(userInitiated: false) }
    }

    nonisolated func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: Error) {
        Task { @MainActor in self.errorMessage = error.localizedDescription }
    }
}
