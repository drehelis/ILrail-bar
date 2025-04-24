import Foundation

struct StationPreferences: Codable {
    var fromStation: String
    var toStation: String
    var upcomingItemsCount: Int
    var launchAtLogin: Bool
    var refreshInterval: Int
    var activeDays: [Bool]
    var activeStartHour: Int
    var activeEndHour: Int
    var walkTimeDurationMin: Int
    var maxTrainChanges: Int
    
    static let defaultPreferences = StationPreferences(
        fromStation: "3700",
        toStation: "2300",
        upcomingItemsCount: 3,
        launchAtLogin: false,
        refreshInterval: 600,
        activeDays: [true, true, true, true, true, false, false], // All days active by default
        activeStartHour: 6, // 6 AM
        activeEndHour: 23, // 11 PM
        walkTimeDurationMin: 0, // Default to 0 minutes
        maxTrainChanges: -1 // Default to allow any number of train changes (unlimited)
    )
}

class PreferencesManager {
    static let shared = PreferencesManager()
    
    private let preferencesKey = "StationPreferences"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    var preferences: StationPreferences {
        get {
            guard let data = userDefaults.data(forKey: preferencesKey),
                  let preferences = try? JSONDecoder().decode(StationPreferences.self, from: data) else {
                return StationPreferences.defaultPreferences
            }
            return preferences
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: preferencesKey)
            }
        }
    }
    
    func savePreferences(fromStation: String, toStation: String, upcomingItemsCount: Int = 3, 
                         launchAtLogin: Bool = false, 
                         refreshInterval: Int = 300, activeDays: [Bool]? = nil, activeStartHour: Int = 6, activeEndHour: Int = 23,
                         walkTimeDurationMin: Int = 0, maxTrainChanges: Int = -1) {
        let currentPrefs = preferences
        preferences = StationPreferences(
            fromStation: fromStation, 
            toStation: toStation, 
            upcomingItemsCount: upcomingItemsCount, 
            launchAtLogin: launchAtLogin,
            refreshInterval: refreshInterval,
            activeDays: activeDays ?? currentPrefs.activeDays,
            activeStartHour: activeStartHour,
            activeEndHour: activeEndHour,
            walkTimeDurationMin: walkTimeDurationMin,
            maxTrainChanges: maxTrainChanges
        )
    }
}

// Station data
struct Station: Identifiable, Hashable {
    let id: String
    let name: String
    
    // Default stations in case fetching fails
    static let defaultStations: [Station] = [
        Station(id: "3700", name: "Tel Aviv - Savidor Center"),
        Station(id: "2300", name: "Haifa - Hof HaCarmel"),
    ]
    
    // Static property to hold stations with thread-safe access
    private static var _allStations: [Station] = defaultStations
    private static let stationsQueue = DispatchQueue(label: "com.ilrailbar.stationsAccess")
    
    static var allStations: [Station] {
        stationsQueue.sync {
            return _allStations
        }
    }
    
    static func setStations(_ stations: [Station]) {
        stationsQueue.async {
            // Only replace if we have stations
            if !stations.isEmpty {
                _allStations = stations
            }
        }
    }
    
    static func fetchStations(completion: @escaping ([Station]?) -> Void) {
        // First check if we have cached stations in UserDefaults
        if let cachedData = UserDefaults.standard.data(forKey: "cachedStationsData") {
            do {
                let response = try JSONDecoder().decode(StationResponse.self, from: cachedData)
                let stations = response.result.map { 
                    Station(id: String($0.stationId), name: $0.stationName) 
                }.sorted { $0.name < $1.name } // Sort by name
                
                if !stations.isEmpty {
                    logDebug("Using \(stations.count) stations from cache")
                    // Return cached stations immediately but still try to fetch fresh ones
                    setStations(stations)
                    NotificationCenter.default.post(name: .stationsLoaded, object: nil)
                    completion(stations)
                    
                    // Continue fetch for the latest data in the background
                    fetchLatestStationsData(completion)
                    return
                }
            } catch {
                logError("Error decoding cached stations: \(error.localizedDescription)")
                // Continue with remote fetch
            }
        }
        
        // If cache handling didn't return early, fetch fresh data
        fetchLatestStationsData(completion)
    }
    
    private static func fetchLatestStationsData(_ completion: @escaping ([Station]?) -> Void) {
        let startTime = Date()
        NetworkManager.shared.fetchStations { result in
            switch result {
            case .success(let remoteStations):
                let stations = remoteStations.map { 
                    Station(id: String($0.stationId), name: $0.stationName) 
                }.sorted { $0.name < $1.name } // Sort by name
                
                // Verify we got stations
                if !stations.isEmpty {
                    let timeElapsed = Date().timeIntervalSince(startTime)
                    logDebug("Successfully loaded \(stations.count) stations in \(String(format: "%.2f", timeElapsed)) seconds")
                    
                    // Update the shared list and notify observers
                    setStations(stations)
                    NotificationCenter.default.post(name: .stationsLoaded, object: nil)
                    
                    completion(stations)
                } else {
                    logWarning("Warning: Received empty stations list")
                    setStations(defaultStations)
                    NotificationCenter.default.post(name: .stationsLoaded, object: nil)
                    completion(defaultStations)
                }
                
            case .failure(let error):
                logError("Error fetching stations: \(error)")
                logWarning("Using default stations as fetching failed")
                setStations(defaultStations)
                NotificationCenter.default.post(name: .stationsLoaded, object: nil)
                completion(defaultStations)
            }
        }
    }
}

// Notification for station data loaded
extension Notification.Name {
    static let reloadPreferencesChanged = Notification.Name("com.ilrailbar.reloadPreferencesChanged")
    static let stationsLoaded = Notification.Name("com.ilrailbar.stationsLoaded")
    static let trainDisplayUpdate = Notification.Name("com.ilrailbar.trainDisplayUpdate")
}
