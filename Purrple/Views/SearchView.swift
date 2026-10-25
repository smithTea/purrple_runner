import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @State private var query = ""

    private var results: [Track] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return library.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.artist.localizedCaseInsensitiveContains(q)
                || $0.album.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ScrollView {
            if query.isEmpty {
                browseGrid
            } else {
                LazyVStack(spacing: Theme.Spacing.tighter2) {
                    let found = results
                    ForEach(Array(found.enumerated()), id: \.element.id) { i, track in
                        TrackRow(track: track) {
                            player.play(found, startAt: i, context: "Search")
                        }
                    }
                    if found.isEmpty {
                        Text("No results for \"\(query)\"")
                            .font(.purrBody)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, Theme.Spacing.looser4)
                    }
                }
                .padding(.horizontal, Theme.Spacing.base)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "What do you want to listen to?")
    }

    /// Colored artist tiles, like the "Browse all" grid.
    private var browseGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            Text("Browse your artists")
                .font(.purrBodyBold)
                .foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.base), GridItem(.flexible())],
                      spacing: Theme.Spacing.base) {
                ForEach(Array(library.artists.enumerated()), id: \.element.id) { i, artist in
                    NavigationLink(value: Route.artist(artist.name)) {
                        ZStack(alignment: .topLeading) {
                            Theme.tileColors[i % Theme.tileColors.count]
                            Text(artist.name)
                                .font(.purrBodyBold)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .padding(Theme.Spacing.tighter)
                            ArtworkView(track: artist.artworkTrack, size: 64)
                                .rotationEffect(.degrees(25))
                                .shadow(radius: 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .offset(x: 14, y: 6)
                        }
                        .frame(height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.base, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.top, Theme.Spacing.tighter2)
    }
}
