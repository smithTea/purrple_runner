import SwiftUI

/// Floating now-playing bar: 56pt tall, 8pt margins and corner radius, 40pt
/// cover, 2pt progress line along the bottom edge.
struct MiniPlayerView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    let onOpen: () -> Void

    private typealias M = Theme.MiniPlayer

    var body: some View {
        if let track = player.current {
            HStack(spacing: Theme.Spacing.tighter2) {
                ArtworkView(track: track, size: M.artworkSize, radius: M.artworkRadius)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.purrCaptionBold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(track.artist)
                        .font(.purrCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                AirPlayButton()
                    .frame(width: M.buttonSize, height: M.buttonSize)

                Button {
                    library.toggleLike(track)
                } label: {
                    Image(systemName: library.isLiked(track) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(library.isLiked(track) ? Theme.accent : Theme.textPrimary)
                        .frame(width: M.buttonSize, height: M.buttonSize)
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: M.buttonSize, height: M.buttonSize)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, M.contentPadding)
            .frame(height: M.height)
            .background(ArtworkStore.shared.backgroundColor(for: track))
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.3))
                        Capsule().fill(Color.white)
                            .frame(width: geo.size.width * player.progress)
                    }
                }
                .frame(height: M.progressHeight)
                .padding(.horizontal, M.contentPadding)
            }
            .clipShape(RoundedRectangle(cornerRadius: M.cornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .padding(.horizontal, M.margin)
            .padding(.bottom, Theme.Spacing.tighter4)
            .animation(.easeInOut(duration: 0.3), value: track.id)
        }
    }
}
