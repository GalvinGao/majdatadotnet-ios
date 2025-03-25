import SwiftUI
import UIKit

struct FilePicker: UIViewControllerRepresentable {
    @Binding var directoriesToSave: [URL]
    @Environment(\.presentationMode) var presentationMode
    @State private var errorMessage: String?
    @State private var sessionId: String = UUID().uuidString
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        self.sessionId = UUID().uuidString
        // Create a temporary directory to hold our files
        let tempDir = FileManager.default.temporaryDirectory
        let sessionDir = tempDir.appendingPathComponent(sessionId)
        
        do {
            var chartDirs: [URL] = []
            // Copy all files into the chart directory
            for directory in directoriesToSave {
                let chartID = directory.lastPathComponent
                let chartDir = sessionDir.appendingPathComponent(chartID)
                // Create the chart directory
                try FileManager.default.createDirectory(at: chartDir, withIntermediateDirectories: true, attributes: nil)
                
                // Remove existing directory if it exists
                if FileManager.default.fileExists(atPath: chartDir.path) {
                    try FileManager.default.removeItem(at: chartDir)
                }
                
                try FileManager.default.copyItem(at: directory, to: chartDir)
                chartDirs.append(chartDir)
            }
            
            // Create the document picker with the chart directory
            let controller = UIDocumentPickerViewController(
                forExporting: chartDirs,
                asCopy: true
            )
            controller.delegate = context.coordinator
            controller.allowsMultipleSelection = false
            return controller
        } catch {
            print("Error preparing folder: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Error preparing folder: \(error.localizedDescription)"
            }
            return UIDocumentPickerViewController(forExporting: [], asCopy: true)
        }
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: FilePicker
        
        init(_ parent: FilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Clean up the temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let sessionID = parent.sessionId
            let sessionDir = tempDir.appendingPathComponent(sessionID)
            try? FileManager.default.removeItem(at: sessionDir)
        }
    }
} 