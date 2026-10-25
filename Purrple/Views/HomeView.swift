import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @Binding var showImporter: Bool

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.looser2) {
                HStack {
                    Text(greeting)
                        .font(.purrTitle)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if library.isScanning { ProgressView().tint(Theme.textSecondary) }
                    Button { showImporter = true } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, Theme.Spacing.base)
                .padding(.top, Theme.Spacing.tighter2)

                if library.tracks.isEmpty {
                    EmptyLibraryView(showImporter: $showImporter)
                } else {
                    shortcutsGrid
                    albumCarousel(title: "Recently added", albums: Array(library.albums.prefix(12)))
                    artistCarousel
                    if library.albums.count > 12 {
                        albumCarousel(title: "More of your music", albums: Array(library.albums.dropFirst(12).shuffled().prefix(12)))
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.looser3)
        }
        .background(
            LinearGradient(colors: [Theme.accentDark.opacity(0.55), Theme.background],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.3))
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Two-column grid of compact tiles at the top of Home.
    private var shortcutsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: Theme.Spacing.tighter2), GridItem(.flexible(), spacing: Theme.Spacing.tighter2)]
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.tighter2) {
            NavigationLink(value: Route.liked) {
                ShortcutTile(title: "Liked Songs") { LikedSongsArtwork(size: 56, radius: 0) }
            }
            ForEach(library.albums.prefix(7)) { album in
                NavigationLink(value: Route.album(album.id)) {
                    ShortcutTile(title: album.title) { ArtworkView(track: album.artworkTrack, size: 56, radius: 0) }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.base)
    }

    private func albumCarousel(title: String, albums: [Album]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Theme.Spacing.base) {
                    ForEach(albums) { album in
                        NavigationLink(value: Route.album(album.id)) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.tighter2) {
                                ArtworkView(track: album.artworkTrack, size: 140)
                                Text(album.title)
                                    .font(.purrCaptionBold)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(.purrCaption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140, alignment: .leading)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.base)
            }
        }
    }

    private var artistCarousel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            SectionHeader(title: "Your artists")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Theme.Spacing.base) {
                    ForEach(library.artists.prefix(15)) { artist in
                        NavigationLink(value: Route.artist(artist.name)) {
                            VStack(spacing: Theme.Spacing.tighter2) {
                                ArtworkView(track: artist.artworkTrack, size: 120, circle: true)
                                Text(artist.name)
                                    .font(.purrCaptionBold)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 120)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.base)
            }
        }
    }
}

private struct ShortcutTile<Art: View>: View {
    let title: String
    @ViewBuilder let art: () -> Art

    var body: some View {
        HStack(spacing: Theme.Spacing.tighter2) {
            art()
            Text(title)
                .font(.purrCaptionBold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(height: 56)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.base, style: .continuous))
    }
}

struct EmptyLibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @Binding var showImporter: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.base) {
            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text("Your library is empty")
                .font(.purrSection)
                .foregroundStyle(Theme.textPrimary)
            Text("Import MP3, FLAC or OGG files, or copy them into\nFiles › On My iPhone › Purrple.")
                .font(.purrCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showImporter = true
            } label: {
                Text("Import music")
                    .font(.purrBodyBold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, Theme.Spacing.looser3)
                    .padding(.vertical, Theme.Spacing.tighter)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(PressScaleStyle())
            Button("Rescan") { Task { await library.rescan() } }
                .font(.purrCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.looser6)
    }
}
