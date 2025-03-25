import Foundation

class DownloadHistory: ObservableObject {
    static let shared = DownloadHistory()
    
    private let defaults = UserDefaults.standard
    private let downloadedChartsKey = "downloadedCharts"
    
    @Published private(set) var downloadedChartIds: Set<String> = []
    
    private init() {
        loadDownloadedCharts()
    }
    
    private func loadDownloadedCharts() {
        if let data = defaults.data(forKey: downloadedChartsKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            downloadedChartIds = decoded
        }
    }
    
    private func saveDownloadedCharts() {
        if let encoded = try? JSONEncoder().encode(downloadedChartIds) {
            defaults.set(encoded, forKey: downloadedChartsKey)
        }
    }
    
    func markAsSaved(_ chartId: String) {
        downloadedChartIds.insert(chartId)
        saveDownloadedCharts()
    }
} 