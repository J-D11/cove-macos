import SwiftUI

struct NowPlayingArtworkView: View {
    let item: NowPlayingItem
    let onOpen: () -> Void
    let onCommand: (NowPlayingCommand) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                artwork
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.42), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(item.externalURL == nil)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(1)

                Text(item.artist ?? item.album ?? sourceLabel)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)

                if item.source == .spotify {
                    playbackControls
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 232, height: 48)
        .padding(.horizontal, 5)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.075 : 0.035))
        }
        .onHover { isHovering = $0 }
        .help(item.helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.helpText)
    }

    private var sourceLabel: String {
        item.source == .spotify ? "Spotify" : "Now Playing"
    }

    private var playbackControls: some View {
        HStack(spacing: 11) {
            playbackButton(symbol: "backward.fill", label: "Previous") {
                onCommand(.previous)
            }
            playbackButton(
                symbol: item.isPlaying == true ? "pause.fill" : "play.fill",
                label: item.isPlaying == true ? "Pause" : "Play"
            ) {
                onCommand(.togglePlayback)
            }
            playbackButton(symbol: "forward.fill", label: "Next") {
                onCommand(.next)
            }
            Circle()
                .fill(Color(red: 0.12, green: 0.84, blue: 0.38))
                .frame(width: 5, height: 5)
            Text("Spotify")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
        .frame(height: 15)
    }

    private func playbackButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
        .help(label)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = item.artwork {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.9), .blue.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
