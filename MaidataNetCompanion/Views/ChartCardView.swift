import SwiftUI
import CachedAsyncImage

struct ChartCardView: View {
    let chart: MaiDataNet.MaiChart
    @State private var relativeTime: String = ""
    @State private var timer: Timer?
    @State private var isPressed = false
    @State private var isCompleted = false
    @State private var showOverlay = true
    @ObservedObject private var downloader = MaidataDownloader.shared
    @ObservedObject private var downloadHistory = DownloadHistory.shared
    var onShowDownloadQueue: () -> Void
    
    private func updateRelativeTime() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: chart.timestamp) else {
            relativeTime = chart.timestamp
            return
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .full
        relativeFormatter.locale = Locale.current
        
        relativeTime = relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    var isSaved: Bool {
        return downloadHistory.downloadedChartIds.contains(chart.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Album Art
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
            
            // Chart Info
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
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            if downloader.downloadItems.first(where: { $0.id == chart.id }) != nil {
                onShowDownloadQueue()
            } else {
                Task {
                    try await MaidataDownloader.shared.addQueue(id: chart.id)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .overlay {
            if let downloadItem = downloader.downloadItems.first(where: { $0.id == chart.id }) {
                ZStack {
                    Color.gray.opacity(0.2)

                    ZStack {
                        Circle()
                            .stroke(lineWidth: 3)
                            .opacity(0.3)
                            .foregroundColor(.white)
                        Circle()
                            .trim(from: 0.0, to: downloadItem.progress)
                            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.white)
                            .rotationEffect(Angle(degrees: 270.0))
                        Image(systemName: downloadItem.progress >= 1 ? "checkmark" : "arrow.down")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .frame(width: 48, height: 48)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(showOverlay ? 1 : 0)
                .onChange(of: downloadItem.progress) { newProgress in
                    if newProgress >= 1 {
                        isCompleted = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showOverlay = false
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            updateRelativeTime()
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                updateRelativeTime()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
