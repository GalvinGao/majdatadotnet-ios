import SwiftUI
import CachedAsyncImage

private struct ChartImageView: View {
    let chart: MajdataNet.MaiChart
    let isSaved: Bool
    
    var body: some View {
        CachedAsyncImage(url: URL(string: "https://majdata.net/api3/api/maichart/\(chart.id)/image")) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if isSaved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .padding(6)
                    .background(.ultraThickMaterial)
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 16, bottomTrailing: 0, topTrailing: 0)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
}

private struct ChartInfoView: View {
    let chart: MajdataNet.MaiChart
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chart.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(chart.artist)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                ForEach(chart.charts, id: \.difficulty) { chartLevel in
                    Text(chartLevel.level)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .frame(minWidth: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: chartLevel.difficulty.color))
                        )
                }
            }
        }
    }
}

struct ChartCardView: View {
    let chart: MajdataNet.MaiChart
    @State private var isPressed = false
    @State private var isCompleted = false
    @State private var showOverlay = true
    @StateObject private var downloader = MNDownloader.shared
    @StateObject private var downloadHistory = DownloadHistory.shared
    var onShowDownloadQueue: () -> Void
    
    private var isSaved: Bool {
        downloadHistory.downloadedChartIds.contains(chart.id)
    }
    
    private var downloadItem: MNDownloadItem? {
        downloader.downloadItems.first(where: { $0.id == chart.id })
    }
    
    var body: some View {
        Button {
            if downloadItem != nil {
                onShowDownloadQueue()
            } else {
                Task {
                    try await MNDownloader.shared.addQueue(id: chart.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ChartImageView(chart: chart, isSaved: isSaved)
                ChartInfoView(chart: chart)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .overlay {
            if let item = downloadItem {
                DownloadOverlayView(progress: item.progress, showOverlay: $showOverlay, isCompleted: $isCompleted)
            }
        }
    }
}

private struct DownloadOverlayView: View {
    let progress: Double
    @Binding var showOverlay: Bool
    @Binding var isCompleted: Bool
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .opacity(0.3)
                    .foregroundColor(.white)
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: 270.0))
                Image(systemName: progress >= 1 ? "checkmark" : "arrow.down")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .frame(width: 48, height: 48)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(showOverlay ? 1 : 0)
        .onChange(of: progress) { newProgress in
            if newProgress >= 1 {
                isCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showOverlay = false
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: progress)
        .animation(.easeOut(duration: 0.3), value: showOverlay)
    }
}

// Add custom button style for smooth animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
