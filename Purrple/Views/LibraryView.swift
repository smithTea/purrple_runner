import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @Binding var showImporter: Bool
    @State private var filter: Filter = .albums

    enum Filter: String, CaseIterable {
        case albums = "Albums", artists = "Artists", songs = "Songs"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.base) {
                HStack {
                    Text("Your Library")
                        .font(.purrTitle)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button { Task { await library.rescan() } } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 18, weight: .semibold))
                    }
                    Button { showImporter = true } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, Theme.Spacing.tighter2)

                HStack(spacing: Theme.Spacing.tighter2) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Chip(title: f.rawValue, selected: filter == f) { filter = f }
                    }
                }

                LazyVStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                    NavigationLink(value: Route.liked) {
                        LibraryRow(title: "Liked Songs", subtitle: "Playlist · \(library.likedIDs.count) songs") {
                            LikedSongsArtwork(size: 64)
                        }
                    }
                    switch filter {
                    case .albums:
                        ForEach(library.albums) { album in
                            NavigationLink(value: Route.album(album.id)) {
                                LibraryRow(title: album.title, subtitle: "Album · \(album.artist)") {
                                    ArtworkView(track: album.artworkTrack, size: 64)
                                }
                            }
                        }
                    case .artists:
                        ForEach(library.artists) { artist in
                            NavigationLink(value: Route.artist(artist.name)) {
                                LibraryRow(title: artist.name, subtitle: "Artist") {
                                    ArtworkView(track: artist.artworkTrack, size: 64, circle: true)
                                }
                            }
                        }
                    case .songs:
                        let songs = library.recentlyAdded
                        ForEach(Array(songs.enumerated()), id: \.element.id) { i, track in
                            TrackRow(track: track) {
                                player.play(songs, startAt: i, context: "Your Library")
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                if library.tracks.isEmpty {
                    EmptyLibraryView(showImporter: $showImporter)
                }
            }
            .padding(.horizontal, Theme.Spacing.base)
            .padding(.bottom, Theme.Spacing.looser3)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct LibraryRow<Art: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let art: () -> Art

    var body: some View {
        HStack(spacing: Theme.Spacing.tighter) {
            art()
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.purrBody)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.purrCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
