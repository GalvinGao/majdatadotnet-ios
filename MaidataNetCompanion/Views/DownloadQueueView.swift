import SwiftUI

struct DownloadQueueView: View {
    @ObservedObject var downloader = MaidataDownloader.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var directoriesToSave: [URL] = []
    
    private var hasCompletedItems: Bool {
        downloader.downloadItems.contains { $0.status == .completed }
    }
    
    private var hasIncompleteItems: Bool {
        downloader.downloadItems.contains { $0.status != .completed }
    }
    
    private var installButtonTitle: String {
        if hasIncompleteItems {
            return "Install Downloaded"
        }
        return "Install All"
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if downloader.downloadItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Downloads")
                            .font(.headline)
                        Text("Tap on any chart to add it to the download queue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Button {
                                Task {
                                    // Collect all completed downloads
                                    let completedItems = downloader.downloadItems.filter { $0.status == .completed }
                                    if !completedItems.isEmpty {
                                        directoriesToSave = completedItems.flatMap { $0.outputDirectory }
                                        // Mark all completed items as saved
                                        for item in completedItems {
                                            DownloadHistory.shared.markAsSaved(item.id)
                                        }
                                        showingFilePicker = true
                                    }
                                }
                            } label: {
                                Label(installButtonTitle, systemImage: "arrow.down.circle.fill")
                            }
                            .disabled(!hasCompletedItems)
                        }
                        
                        Section {
                            ForEach(downloader.downloadItems) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    
                                    if item.status == .downloading {
                                        ProgressView(value: item.progress)
                                            .progressViewStyle(.linear)
                                    }
                                    
                                    HStack {
                                        switch item.status {
                                        case .queued:
                                            Label("Queued", systemImage: "clock")
                                                .foregroundColor(.secondary)
                                        case .downloading:
                                            Label("Downloading", systemImage: "arrow.down.circle")
                                                .foregroundColor(.blue)
                                        case .completed:
                                            Label("Completed", systemImage: "checkmark.circle")
                                                .foregroundColor(.green)
                                        case .failed:
                                            Label("Failed", systemImage: "exclamationmark.circle")
                                                .foregroundColor(.red)
                                        }
                                        
                                        if item.status == .failed {
                                            Button("Retry") {
                                                Task {
                                                    try? await downloader.addQueue(id: item.id)
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Download Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePicker(directoriesToSave: $directoriesToSave)
        }
        .onAppear {
            // Force a UI update when the view appears
            downloader.objectWillChange.send()
        }
    }
} 