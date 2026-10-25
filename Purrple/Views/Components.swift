import AVKit
import SwiftUI

// MARK: - Artwork

struct ArtworkView: View {
    let track: Track?
    var size: CGFloat? = nil
    var radius: CGFloat = Theme.Radius.base
    var circle = false

    var body: some View {
        // A square placeholder sized first, with the art laid over it, so a
        // non-square cover can't push the layout wider than the square.
        Color.clear
            .frame(width: size, height: size)
            .aspectRatio(1, contentMode: .fit)
            .overlay { artwork }
            .clipShape(circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    @ViewBuilder
    private var artwork: some View {
        if let track, let image = ArtworkStore.shared.image(for: track) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [Theme.highlight, Theme.elevated], startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { geo in
                    Image(systemName: "music.note")
                        .font(.system(size: geo.size.width * 0.38))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }
}

/// The purple gradient tile used for "Liked Songs".
struct LikedSongsArtwork: View {
    var size: CGFloat? = nil
    var radius: CGFloat = Theme.Radius.base

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.accentDark, Theme.accentBright], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Image(systemName: "heart.fill")
                    .font(.system(size: geo.size.width * 0.36))
                    .foregroundStyle(.white)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Buttons

/// Big round purple play/pause button.
struct PlayCircleButton: View {
    let isPlaying: Bool
    var size: CGFloat = 56
    var fill: Color = Theme.accent
    var iconColor: Color = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(iconColor)
                .offset(x: isPlaying ? 0 : size * 0.03)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AirPlayButton: UIViewRepresentable {
    var tint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tint
        view.activeTintColor = UIColor(Theme.accent)
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = tint
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.purrCaption)
                .foregroundStyle(selected ? Color.black : Color.white)
                .padding(.horizontal, Theme.Spacing.tighter)
                .padding(.vertical, Theme.Spacing.tighter3)
                .background(Capsule().fill(selected ? Theme.accent : Theme.elevated))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rows

/// Animated bars shown next to the playing track.
struct PlayingIndicator: View {
    let animating: Bool
    @State private var phase = false

    private static let heightsA: [CGFloat] = [6, 12, 8]
    private static let heightsB: [CGFloat] = [12, 5, 11]

    private func height(_ i: Int) -> CGFloat {
        guard animating else { return 4 }
        return phase ? Self.heightsA[i] : Self.heightsB[i]
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.accent)
                    .frame(width: 3, height: height(i))
            }
        }
        .frame(width: 14, height: 12, alignment: .bottom)
        .animation(animating ? .easeInOut(duration: 0.4).repeatForever() : .default, value: phase)
        .onAppear { phase.toggle() }
    }
}

struct TrackRow: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    let track: Track
    var showArtwork = true
    var number: Int? = nil
    let onTap: () -> Void

    private var isCurrent: Bool { player.current?.id == track.id }

    var body: some View {
        HStack(spacing: Theme.Spacing.tighter) {
            if showArtwork {
                ArtworkView(track: track, size: 48)
            } else if let number {
                Text("\(number)")
                    .font(.purrBody)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.tighter3) {
                    if isCurrent { PlayingIndicator(animating: player.isPlaying) }
                    Text(track.title)
                        .font(.purrBody)
                        .foregroundStyle(isCurrent ? Theme.accent : Theme.textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    if library.isLiked(track) {
                        Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(Theme.accent)
                    }
                    Text(track.artist)
                        .font(.purrCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            TrackMenu(track: track) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 44)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct TrackMenu<MenuLabel: View>: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    let track: Track
    @ViewBuilder let label: () -> MenuLabel
    @State private var confirmDelete = false

    var body: some View {
        Menu {
            Button {
                library.toggleLike(track)
            } label: {
                if library.isLiked(track) {
                    Label("Remove from Liked Songs", systemImage: "heart.slash")
                } else {
                    Label("Add to Liked Songs", systemImage: "heart")
                }
            }
            Section("\(track.fileExtension) · \(formatTime(track.duration))") {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete File", systemImage: "trash")
                }
            }
        } label: {
            label()
        }
        .confirmationDialog("Delete \"\(track.title)\" from this device?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                player.remove(track)
                library.delete(track)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.purrSection)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.base)
    }
}
