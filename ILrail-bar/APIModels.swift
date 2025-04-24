import Foundation

// API response models for stations
struct StationResponse: Codable {
    let creationDate: String
    let version: String
    let successStatus: Int
    let statusCode: Int
    let errorMessages: String?
    let result: [RemoteStation]
}

struct RemoteStation: Codable {
    let stationId: Int
    let stationName: String
}

struct APIResponse: Decodable {
    let result: TrainResult
}

struct TrainSchedule: Equatable {
    let trainNumber: String
    let departureTime: Date
    let arrivalTime: Date
    let platform: String?
    let fromStationName: String
    let toStationName: String
    let trainChanges: Int
    let allTrainNumbers: [String]
    let isFromCache: Bool
    let cacheAgeMinutes: Int?
}

struct TrainResult: Decodable {
    let travels: [TravelItem]
}

struct TravelItem: Decodable {
    let departureTime: String
    let arrivalTime: String
    let trains: [TrainData]
}

struct TrainData: Decodable {
    let trainNumber: String
    let departureTime: Date
    let arrivalTime: Date
    let platform: String?
    let fromStationName: String?
    let toStationName: String?
    let originPlatform: Int
    let destPlatform: Int
    
    enum CodingKeys: String, CodingKey {
        case trainNumber
        case departureTime
        case arrivalTime
        case originPlatform
        case destPlatform
        case fromStationName = "orignStation" // Note: API has a typo "orignStation" instead of "originStation"
        case toStationName = "destinationStation"
        case stopStations // Added to explicitly ignore this key
        case routeStations // Added to explicitly ignore this key
        // Excluded: routeStations, stopStations - we'll explicitly ignore these
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle trainNumber which can be either an Int or a String
        if let trainNumberInt = try? container.decode(Int.self, forKey: .trainNumber) {
            trainNumber = String(trainNumberInt)
        } else {
            trainNumber = try container.decode(String.self, forKey: .trainNumber)
        }
        
        departureTime = try container.decode(Date.self, forKey: .departureTime)
        arrivalTime = try container.decode(Date.self, forKey: .arrivalTime)
        originPlatform = try container.decode(Int.self, forKey: .originPlatform)
        destPlatform = try container.decode(Int.self, forKey: .destPlatform)
        
        // Handle optional fields or convert types as needed
        if let fromStationId = try? container.decode(Int.self, forKey: .fromStationName) {
            fromStationName = String(fromStationId)
        } else {
            fromStationName = nil
        }
        
        if let toStationId = try? container.decode(Int.self, forKey: .toStationName) {
            toStationName = String(toStationId)
        } else {
            toStationName = nil
        }
        
        // Set platform as string from destPlatform
        platform = String(destPlatform)
        
        // Explicitly ignore stopStations and routeStations
        // We're not storing these values, just making sure they're properly skipped during decoding
        _ = try? container.decodeNil(forKey: .stopStations)
        _ = try? container.decodeNil(forKey: .routeStations)
    }
}