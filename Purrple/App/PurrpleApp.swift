import SwiftUI

@main
struct PurrpleApp: App {
    @StateObject private var library: LibraryStore
    @StateObject private var player: PlayerController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let library = LibraryStore()
        _library = StateObject(wrappedValue: library)
        _player = StateObject(wrappedValue: PlayerController(library: library))
        Self.styleUIKitChrome()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { await library.rescan() }
        }
        .onChange(of: scenePhase) { phase in
            // Pick up files dropped in through the Files app or Finder.
            if phase == .active { Task { await library.rescan() } }
        }
    }

    private static func styleUIKitChrome() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithTransparentBackground()
        tabBar.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabBar.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        for layout in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            layout.normal.iconColor = UIColor(Theme.textSecondary)
            layout.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.textSecondary),
                                                 .font: UIFont.systemFont(ofSize: 10, weight: .medium)]
            layout.selected.iconColor = .white
            layout.selected.titleTextAttributes = [.foregroundColor: UIColor.white,
                                                   .font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = .white
    }
}
