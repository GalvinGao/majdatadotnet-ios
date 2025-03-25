import SwiftUI
import CachedAsyncImage

struct ChartDetailView: View {
    let chart: MaiDataNet.MaiChart
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Album Art
                    CachedAsyncImage(url: URL(string: "https://majdata.net/api3/api/maichart/\(chart.id)/image")) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    ProgressView()
                                        .controlSize(.large)
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 4)
                    .matchedGeometryEffect(id: "albumArt-\(chart.id)", in: namespace)
                    .padding(.horizontal)
                    
                    // Chart Info
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chart.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(chart.artist)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        
                        // Difficulty Levels
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Difficulty Levels")
                                .font(.system(size: 16, weight: .semibold))
                            
                            HStack(spacing: 8) {
                                ForEach(chart.charts, id: \.difficulty) { chartLevel in
                                    Text(chartLevel.level)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: chartLevel.difficulty.color))
                                        )
                                }
                            }
                        }
                        
                        // Additional Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Info")
                                .font(.system(size: 16, weight: .semibold))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Designer: \(chart.designer)")
                                Text("Uploader: \(chart.uploader)")
                                Text("Uploaded: \(chart.timestamp)")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
        }
    }
} 