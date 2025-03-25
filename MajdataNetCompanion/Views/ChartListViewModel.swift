import Foundation
import SwiftUI

@MainActor
class ChartListViewModel: ObservableObject {
    // MARK: - State
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    // MARK: - Published Properties
    @Published private(set) var charts: [MajdataNet.MaiChart] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var hasMorePages = true
    @Published var searchInput: String = ""
    @Published var selectedSort: MajdataNet.Sort = .none

    // MARK: - Private Properties
    private var currentPage = 0
    private var loadingTask: Task<Void, Never>?

    // MARK: - Public Methods
    func loadCharts(reset: Bool = false) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new loading task
        loadingTask = Task {
            if reset {
                charts = []
                currentPage = 0
                hasMorePages = true
            }

            // Only check hasMorePages for subsequent loads, not the initial load
            if !reset && !hasMorePages {
                return
            }

            // Don't start a new load if we're already loading
            guard state != .loading else { return }

            state = .loading

            do {
                let newCharts = try await MajdataNet.fetchCharts(
                    sort: selectedSort,
                    page: currentPage,
                    search: searchInput.isEmpty ? nil : searchInput
                )

                if !Task.isCancelled {
                    if newCharts.isEmpty {
                        hasMorePages = false
                    } else {
                        charts.append(contentsOf: newCharts)
                        currentPage += 1
                    }
                    state = .loaded
                }
            } catch {
                if !Task.isCancelled {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    func refresh() async {
        selectedSort = .none
        searchInput = ""
        await loadCharts(reset: true)
    }

    func loadMoreIfNeeded() async {
        guard hasMorePages && state == .loaded else { return }
        await loadCharts()
    }

    // MARK: - Helper Methods
    func sortTitle(for sort: MajdataNet.Sort) -> String {
        switch sort {
        case .none: return "Latest"
        case .like: return "Most Liked"
        case .comment: return "Most Commented"
        case .play: return "Most Played"
        }
    }
} 