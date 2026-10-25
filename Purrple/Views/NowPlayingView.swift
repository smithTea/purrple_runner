import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var scrubPosition: Double?
    @State private var showQueue = false

    var body: some View {
        let track = player.current
        let color = ArtworkStore.shared.backgroundColor(for: track)

        VStack(spacing: 0) {
            header
                .padding(.top, Theme.Spacing.tighter2)

            Spacer(minLength: Theme.Spacing.looser2)

            ArtworkView(track: track, radius: Theme.Radius.larger2)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                .padding(.horizontal, Theme.Spacing.looser2)
                .scaleEffect(player.isPlaying ? 1 : 0.92)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: player.isPlaying)

            Spacer(minLength: Theme.Spacing.looser3)

            titleRow(track)
                .padding(.horizontal, Theme.Spacing.looser2)

            scrubber
                .padding(.horizontal, Theme.Spacing.looser2)
                .padding(.top, Theme.Spacing.looser)

            controls
                .padding(.horizontal, Theme.Spacing.looser2)
                .padding(.top, Theme.Spacing.tighter2)

            HStack {
                AirPlayButton()
                    .frame(width: 32, height: 32)
                Spacer()
                Button { showQueue = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, Theme.Spacing.looser2)
            .padding(.top, Theme.Spacing.base)
            .padding(.bottom, Theme.Spacing.looser2)
        }
        .background(
            LinearGradient(colors: [color, color.opacity(0.6), Theme.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: track?.id)
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in dragOffset = max(0, value.translation.height) }
                .onEnded { value in
                    if value.translation.height > 140 || value.predictedEndTranslation.height > 400 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) { dragOffset = 0 }
                    }
                }
        )
        .sheet(isPresented: $showQueue) {
            QueueView()
                .presentationDetents([.medium, .large])
        }
        .onChange(of: player.current) { current in
            if current == nil { dismiss() }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("PLAYING FROM")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)
                Text(player.context)
                    .font(.purrCaptionBold)
                    .lineLimit(1)
            }
            Spacer()
            if let track = player.current {
                TrackMenu(track: track) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, Theme.Spacing.tighter2)
    }

    private func titleRow(_ track: Track?) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Theme.Spacing.tighter4) {
                Text(track?.title ?? "Not playing")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(track?.artist ?? "")
                    .font(.purrBody)
                    .foregroundStyle(Theme.textSecondary)
            }
            .lineLimit(1)
            Spacer()
            if let track {
                let liked = library.isLiked(track)
                Button { library.toggleLike(track) } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundStyle(liked ? Theme.accent : Theme.textPrimary)
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    private var scrubber: some View {
        let shown = scrubPosition ?? player.progress
        return VStack(spacing: Theme.Spacing.tighter3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule().fill(Color.white)
                        .frame(width: geo.size.width * shown)
                    Circle()
                        .fill(Color.white)
                        .frame(width: scrubPosition == nil ? 12 : 16)
                        .offset(x: geo.size.width * shown - (scrubPosition == nil ? 6 : 8))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            scrubPosition = min(1, max(0, value.location.x / geo.size.width))
                        }
                        .onEnded { _ in
                            if let position = scrubPosition {
                                player.seek(to: position * player.duration)
                            }
                            scrubPosition = nil
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(formatTime(shown * player.duration))
                Spacer()
                Text("-" + formatTime(player.duration - shown * player.duration))
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var controls: some View {
        HStack {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(player.shuffle ? Theme.accent : Theme.textPrimary)
                    .overlay(alignment: .bottom) { activeDot(player.shuffle) }
            }
            Spacer()
            Button { player.previous() } label: {
                Image(systemName: "backward.end.fill").font(.system(size: 30))
            }
            Spacer()
            PlayCircleButton(isPlaying: player.isPlaying, size: 68, fill: .white, iconColor: .black) {
                player.togglePlayPause()
            }
            Spacer()
            Button { player.next() } label: {
                Image(systemName: "forward.end.fill").font(.system(size: 30))
            }
            Spacer()
            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(player.repeatMode == .off ? Theme.textPrimary : Theme.accent)
                    .overlay(alignment: .bottom) { activeDot(player.repeatMode != .off) }
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .buttonStyle(PressScaleStyle())
    }

    @ViewBuilder
    private func activeDot(_ visible: Bool) -> some View {
        if visible {
            Circle().fill(Theme.accent).frame(width: 4, height: 4).offset(y: 10)
        }
    }
}

private struct QueueView: View {
    @EnvironmentObject private var player: PlayerController

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(player.queue.enumerated()), id: \.element.id) { i, track in
                    HStack(spacing: Theme.Spacing.tighter) {
                        ArtworkView(track: track, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.purrBody)
                                .foregroundStyle(i == player.index ? Theme.accent : Theme.textPrimary)
                            Text(track.artist)
                                .font(.purrCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { player.playQueueItem(at: i) }
                    .listRowBackground(Theme.elevated)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
