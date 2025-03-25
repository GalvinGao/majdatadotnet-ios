import SwiftUI

struct ChartListView: View {
    @ObservedObject var viewModel: ChartListViewModel
    @State private var scrollOffset: CGFloat = 0
    @State private var isLoadingMore = false
    @State private var showingDownloadQueue = false
    @State private var downloadButtonScale: CGFloat = 1.0

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Chart Grid
                ScrollView {
                    ScrollTrackingView { offset in
                        scrollOffset = offset
                        checkAndLoadMore()
                    }
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.charts, id: \.id) { chart in
                            ChartCardView(chart: chart, onShowDownloadQueue: {
                                showingDownloadQueue = true
                            })
                        }
                    }
                    .padding([.bottom, .horizontal])
                    .padding(.horizontal, 8)

                    if case .loading = viewModel.state {
                        ProgressView()
                            .padding()
                    }
                }
                .coordinateSpace(name: "scroll")
            }
            .navigationTitle("majdata.net")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchInput,
                prompt: "Search charts..."
            )
            .onChange(of: viewModel.searchInput) { _ in
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await viewModel.loadCharts(reset: true)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                downloadButtonScale = 1.2
                            }
                            showingDownloadQueue = true
                        } label: {
                            Label("Downloads", systemImage: "arrow.down.circle")
                        }
                        .scaleEffect(downloadButtonScale)
                        .onChange(of: downloadButtonScale) { newValue in
                            if newValue == 1.2 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    downloadButtonScale = 1.0
                                }
                            }
                        }
                        
                        Menu {
                            ForEach([MaiDataNet.Sort.none, .like, .comment, .play], id: \.self) { sort in
                                Button(action: {
                                    viewModel.selectedSort = sort
                                    Task {
                                        await viewModel.loadCharts(reset: true)
                                    }
                                }) {
                                    HStack {
                                        Text(viewModel.sortTitle(for: sort))
                                        if viewModel.selectedSort == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("third-party client")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            Task {
                await viewModel.loadCharts()
            }
        }
        .overlay {
            if case .error(let message) = viewModel.state {
                VStack {
                    Text(message)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button("Retry") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(isPresented: $showingDownloadQueue) {
            DownloadQueueView()
        }
    }
    
    private func checkAndLoadMore() {
        // Load more when user scrolls within 1000 points of the bottom
        if scrollOffset < -1000 && !isLoadingMore && viewModel.hasMorePages {
            isLoadingMore = true
            Task {
                await viewModel.loadMoreIfNeeded()
                isLoadingMore = false
            }
        }
    }
} 