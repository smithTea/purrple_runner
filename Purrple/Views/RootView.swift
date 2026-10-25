import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @State private var tab: Tab = .home
    @State private var showNowPlaying = false
    @State private var showImporter = false

    enum Tab { case home, search, library }

    var body: some View {
        TabView(selection: $tab) {
            screen { HomeView(showImporter: $showImporter) }
                .tabItem { Label("Home", systemImage: tab == .home ? "house.fill" : "house") }
                .tag(Tab.home)

            screen { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            screen { LibraryView(showImporter: $showImporter) }
                .tabItem { Label("Your Library", systemImage: tab == .library ? "books.vertical.fill" : "books.vertical") }
                .tag(Tab.library)
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: Self.importTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await library.importItems(urls) }
            case .failure(let error):
                library.lastError = error.localizedDescription
            }
        }
        .alert("Playback error", isPresented: playerErrorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
        .alert("Library", isPresented: libraryErrorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.lastError ?? "")
        }
    }

    /// A tab's navigation stack, with the floating mini player above the tab bar.
    private func screen<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .background(Theme.background.ignoresSafeArea())
                .navigationDestination(for: Route.self) { CollectionView(route: $0) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerView { showNowPlaying = true }
        }
    }

    private var playerErrorShown: Binding<Bool> {
        Binding(get: { player.errorMessage != nil }, set: { if !$0 { player.errorMessage = nil } })
    }

    private var libraryErrorShown: Binding<Bool> {
        Binding(get: { library.lastError != nil }, set: { if !$0 { library.lastError = nil } })
    }

    static let importTypes: [UTType] = {
        var types: [UTType] = [.audio, .mp3, .folder]
        for ext in ["flac", "ogg", "oga", "opus", "wv", "ape", "mpc"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }()
}
