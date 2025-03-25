import Foundation
import SwiftUI

enum MaidataFileType: String {
    case track = "track"
    case chart = "chart"
    case image = "image"
    case video = "video"
    
    var urlSubPath: String {
        switch self {
        case .track: return "track"
        case .chart: return "chart"
        case .image: return "image?fullImage=true"
        case .video: return "video"
        }
    }
    
    var filename: String {
        switch self {
        case .track: return "track.mp3"
        case .chart: return "maidata.txt"
        case .image: return "bg.jpg"
        case .video: return "bg.mp4"
        }
    }
    
    var humanizedName: String {
        switch self {
        case .track: return "Audio Track"
        case .chart: return "Chart"
        case .image: return "Image"
        case .video: return "Video"
        }
    }
    
    var weight: Double {
        switch self {
        case .track: return 1.0
        case .chart: return 0.01
        case .image: return 1.0
        case .video: return 1.2
        }
    }
}

class MaidataDownloadItem: ObservableObject, Identifiable {
    let id: String
    @Published var title: String
    @Published var status: DownloadStatus = .queued
    @Published var progress: Double = 0
    @Published var error: Error?
    @Published var downloadedFiles: [URL] = []
    @Published var outputDirectory: URL?
    
    enum DownloadStatus {
        case queued
        case downloading
        case completed
        case failed
    }
    
    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

class MaidataDownloader: ObservableObject {
    static let shared = MaidataDownloader()
    
    static let FILENAME_MAP = [
        "track": "track.mp3",
        "chart": "maidata.txt",
        "image?fullImage=true": "bg.jpg",
        "video": "bg.mp4"
    ]
    
    static let HUMANIZED_NAMES: [String: String] = [
        "track": "Audio Track",
        "chart": "Chart",
        "image?fullImage=true": "Image",
        "video": "Video"
    ]
    
    static let FILE_WEIGHTS: [String: Double] = [
        "track": 1.0,
        "chart": 0.01,
        "image?fullImage=true": 1.0,
        "video": 1.2
    ]
    
    private let downloadQueue = DispatchQueue(label: "com.maidatanet.downloader", qos: .userInitiated)
    @Published private(set) var downloadItems: [MaidataDownloadItem] = []
    private var activeDownloads: [String: Bool] = [:]
    
    private init() {}
    
    private func sanitizeDirectoryName(_ name: String) -> String {
        // Character mapping for invalid directory characters
        let invalidChars: [Character: Character] = [
            "/": "／",  // Full-width forward slash
            "\\": "＼", // Full-width backslash
        ]
        
        return String(name.map { invalidChars[$0] ?? $0 })
    }
    
    private func parseMaidataTitle(from data: String, fallbackID: String) -> String {
        // Split by newlines and look for the title line
        let lines = data.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("&title=") {
                // Remove the &title= prefix and return the title
                return String(line.dropFirst(7))
            }
        }
        // Fallback to the ID if title is not found
        return fallbackID
    }
    
    private func saveFile(from tempFileURL: URL, to fileURL: URL, fileType: MaidataFileType) throws {
        let fileManager = FileManager.default
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        // Move the downloaded file to the final location
        try fileManager.moveItem(at: tempFileURL, to: fileURL)
        print("Successfully downloaded and saved \(fileType.filename)")
    }
    
    private func downloadFile(id: String, fileType: MaidataFileType, downloadItem: MaidataDownloadItem) async throws -> URL {
        // Construct the download URL
        let urlString = "https://majdata.net/api3/api/maichart/\(id)/\(fileType.urlSubPath)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "MaidataNetCompanion", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for \(fileType.humanizedName)"])
        }
        
        print("Starting download for \(fileType.humanizedName) from \(urlString)")
        
        // Create a dedicated URLSession with a delegate for progress tracking
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        
        // Start the download and wait for completion
        let (tempFileURL, response) = try await session.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "MaidataNetCompanion", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid response for \(fileType.humanizedName)"])
        }
        
        // Update progress based on completed files
        await MainActor.run {
            downloadItem.progress = Double(downloadItem.downloadedFiles.count + 1) / Double(MaidataDownloader.FILENAME_MAP.count)
            objectWillChange.send()
        }
        
        return tempFileURL
    }
    
    private func processDownload(_ downloadItem: MaidataDownloadItem) async throws -> URL {
        // Create a FileManager instance
        let fileManager = FileManager.default
        
        // Get the Documents directory
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "MaidataNetCompanion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access Documents directory"])
        }
        
        // First download and parse the chart file to get the title
        let chartURLString = "https://majdata.net/api3/api/maichart/\(downloadItem.id)/chart"
        guard let chartURL = URL(string: chartURLString) else {
            throw NSError(domain: "MaidataNetCompanion", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid chart URL"])
        }
        
        // Create a dedicated session for the chart download
        let chartSession = URLSession(configuration: .default)
        let (chartData, _) = try await chartSession.data(from: chartURL)
        guard let chartString = String(data: chartData, encoding: .utf8) else {
            throw NSError(domain: "MaidataNetCompanion", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not decode chart data"])
        }
        
        let title = parseMaidataTitle(from: chartString, fallbackID: downloadItem.id)
        
        // Update the title once we have it
        await MainActor.run {
            downloadItem.title = title
            objectWillChange.send()
        }
        
        let sanitizedTitle = sanitizeDirectoryName(title)
        
        // Create a subdirectory with the sanitized title
        let titleDirectory = documentsDirectory.appendingPathComponent(sanitizedTitle)
        
        // Create the directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: titleDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw NSError(domain: "MaidataNetCompanion", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create directory: \(error)"])
        }
        
        // Create async tasks for each download
        async let downloadTasks = withThrowingTaskGroup(of: Void.self) { group in
            for fileType in [MaidataFileType.track, .chart, .image, .video] {
                group.addTask {
                    // Download the file
                    let tempFileURL = try await self.downloadFile(id: downloadItem.id, fileType: fileType, downloadItem: downloadItem)
                    
                    // Create file URL in the title directory
                    let fileURL = titleDirectory.appendingPathComponent(fileType.filename)
                    print("Saving \(fileType.humanizedName) to: \(fileURL.path)")
                    
                    // Save the file
                    try self.saveFile(from: tempFileURL, to: fileURL, fileType: fileType)
                    
                    // Add file to downloaded files
                    await MainActor.run {
                        downloadItem.downloadedFiles.append(fileURL)
                        self.objectWillChange.send()
                    }
                }
            }
            
            // Wait for all downloads to complete
            try await group.waitForAll()
        }
        
        // Wait for all downloads to complete
        try await downloadTasks
        
        return titleDirectory
    }
    
    func addQueue(id: String) async throws {
        // Silently ignore if this ID is already being downloaded
        if activeDownloads[id] == true {
            return
        }
        
        // Create a temporary download item with just the ID
        let downloadItem = MaidataDownloadItem(id: id, title: "Loading...")
        
        // Add to queue
        await MainActor.run {
            downloadItems.append(downloadItem)
            objectWillChange.send()
        }
        
        // Mark this ID as being downloaded
        activeDownloads[id] = true
        defer { activeDownloads[id] = false }
        
        do {
            // Update status to downloading
            await MainActor.run {
                downloadItem.status = .downloading
                objectWillChange.send()
            }
            
            // Process the download
            let outputDirectory = try await processDownload(downloadItem)
            
            // Update status to completed
            await MainActor.run {
                downloadItem.status = .completed
                downloadItem.progress = 1.0
                downloadItem.outputDirectory = outputDirectory
                objectWillChange.send()
            }
        } catch {
            // Update status to failed
            await MainActor.run {
                downloadItem.status = .failed
                downloadItem.error = error
                objectWillChange.send()
            }
            throw error
        }
    }
}
