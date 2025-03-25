import Alamofire
import Foundation

// MARK: - MaiDataNet
enum MaiDataNet {
    // MARK: - Query Parameters
    enum Sort: String {
        case none = ""
        case like = "likep"
        case comment = "commp"
        case play = "playp"
    }

    // MARK: - Difficulty
    enum Difficulty: String, CaseIterable {
        case easy
        case basic
        case advanced
        case expert
        case master
        case remaster
        case utage
        
        var color: Int {
            switch self {
            case .easy: return 0x4A90E2  // Blue
            case .basic: return 0x22BB5B  // Green
            case .advanced: return 0xFB9C2D  // Orange
            case .expert: return 0xF64861  // Red
            case .master: return 0x9E45E2  // Purple
            case .remaster: return 0xBA67F8  // Light Purple
            case .utage: return 0xFF69B4  // Rose Pink
            }
        }
    }

    // MARK: - Chart Level
    struct ChartLevel: Equatable, Sendable {
        let difficulty: Difficulty
        let level: String
    }

    // MARK: - MaiChart
    struct MaiChart: Equatable, Sendable {
        let id: String
        let title: String
        let artist: String
        let designer: String
        let description: String
        let charts: [ChartLevel]
        let uploader: String
        let uploaderID: String
        let timestamp: String
        let hash: String
    }
}

// MARK: - API
extension MaiDataNet {
    static func fetchCharts(
        sort: Sort = .none,
        page: Int = 0,
        search: String? = nil
    ) async throws -> [MaiChart] {
        print("fetchCharts: sort=\(sort), page=\(page), search=\(search)")

        let parameters: [String: Any] = {
            var params: [String: Any] = [:]

            if !sort.rawValue.isEmpty {
                params["sort"] = sort.rawValue
            }

            if page > 0 {
                params["page"] = page
            }

            if let search = search, !search.isEmpty {
                params["search"] = search
            }

            return params
        }()

        return try await AF.request(
            "https://majdata.net/api3/api/maichart/list",
            parameters: parameters
        )
        .serializingDecodable([MaiChart].self)
        .value
    }
}

// MARK: - Codable
extension MaiDataNet.MaiChart: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, title, artist, designer, description, levels, uploader, uploaderID, timestamp, hash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        designer = try container.decode(String.self, forKey: .designer)
        description = try container.decode(String.self, forKey: .description)
        
        // Convert levels array to ChartLevel array
        let levelsArray = try container.decode([String?].self, forKey: .levels)
        charts = zip(MaiDataNet.Difficulty.allCases, levelsArray)
            .compactMap { difficulty, level in
                guard let level = level, !level.isEmpty else { return nil }
                return MaiDataNet.ChartLevel(difficulty: difficulty, level: level)
            }
        
        uploader = try container.decode(String.self, forKey: .uploader)
        uploaderID = try container.decode(String.self, forKey: .uploaderID)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        hash = try container.decode(String.self, forKey: .hash)
    }
}
