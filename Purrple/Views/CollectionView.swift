import SwiftUI

/// Navigation targets. Routes carry ids, and the view looks the tracks up in
/// the library, so a page stays current while files are added or deleted.
enum Route: Hashable {
    case album(String)
    case artist(String)
    case liked
    case allSongs
}

/// Album / artist / playlist-style page: gradient header, big cover, actions
/// row with the purple play button, then the track list.
struct CollectionView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    let route: Route

    private struct Content {
        var title: String
        var subtitle: String
        var tracks: [Track]
        var artworkTrack: Track?
        var numbered = false
        var circleArt = false
        var liked = false
    }

    private var content: Content {
        switch route {
        case .album(let id):
            let album = library.albums.first { $0.id == id }
            return Content(title: album?.title ?? "Album", subtitle: album.map { "Album · \($0.artist)" } ?? "",
                           tracks: album?.tracks ?? [], artworkTrack: album?.artworkTrack, numbered: true)
        case .artist(let name):
            let artist = library.artists.first { $0.name == name }
            return Content(title: name, subtitle: "Artist", tracks: artist?.tracks ?? [],
                           artworkTrack: artist?.artworkTrack, circleArt: true)
        case .liked:
            return Content(title: "Liked Songs", subtitle: "Playlist", tracks: library.likedTracks, liked: true)
        case .allSongs:
            return Content(title: "All Songs", subtitle: "Playlist", tracks: library.recentlyAdded)
        }
    }

    var body: some View {
        let content = self.content
        let headerColor = content.liked ? Theme.accentDark : ArtworkStore.shared.backgroundColor(for: content.artworkTrack)
        let playingHere = player.context == content.title && content.tracks.contains { $0.id == player.current?.id }

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.base) {
                Group {
                    if content.liked {
                        LikedSongsArtwork(size: 220)
                    } else {
                        ArtworkView(track: content.artworkTrack, size: 220, circle: content.circleArt)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.tighter2)

                VStack(alignment: .leading, spacing: Theme.Spacing.tighter4) {
                    Text(content.title)
                        .font(.purrTitle)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(content.subtitle) · \(content.tracks.count) songs · \(formatTime(content.tracks.reduce(0) { $0 + $1.duration }))")
                        .font(.purrCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.base)

                HStack(spacing: Theme.Spacing.looser2) {
                    Spacer()
                    Button {
                        player.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(player.shuffle ? Theme.accent : Theme.textSecondary)
                    }
                    PlayCircleButton(isPlaying: playingHere && player.isPlaying) {
                        if playingHere {
                            player.togglePlayPause()
                        } else {
                            player.play(content.tracks, context: content.title)
                        }
                    }
                    .disabled(content.tracks.isEmpty)
                }
                .padding(.horizontal, Theme.Spacing.base)

                LazyVStack(spacing: Theme.Spacing.tighter2) {
                    ForEach(Array(content.tracks.enumerated()), id: \.element.id) { i, track in
                        TrackRow(track: track, showArtwork: !content.numbered,
                                 number: content.numbered ? (track.trackNumber ?? i + 1) : nil) {
                            player.play(content.tracks, startAt: i, context: content.title)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.base)

                if content.tracks.isEmpty {
                    Text(content.liked ? "Songs you like will appear here.\nTap the heart on any song." : "Nothing here yet.")
                        .font(.purrBody)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.looser4)
                }
            }
            .padding(.bottom, Theme.Spacing.looser3)
        }
        .background(
            LinearGradient(colors: [headerColor, Theme.background], startPoint: .top, endPoint: .init(x: 0.5, y: 0.45))
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
