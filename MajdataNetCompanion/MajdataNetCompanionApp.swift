//
//  MajdataNetCompanionApp.swift
//  MajdataNetCompanion
//
//  Created by Galvin on 2025/03/25.
//

import Alamofire
import SwiftData
import SwiftUI

@main
struct MajdataNetCompanionApp: App {
    init() {
        // Configure a larger URL cache for images
        // Set memory capacity to 50MB and disk capacity to 1GB
        let cache = URLCache(memoryCapacity: 200 * 1024 * 1024,
                           diskCapacity: 1024 * 1024 * 1024)
        URLCache.shared = cache
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
