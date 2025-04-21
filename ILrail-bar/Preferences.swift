import Foundation

struct StationPreferences: Codable {
    var fromStation: String
    var toStation: String
    var upcomingItemsCount: Int
    var launchAtLogin: Bool
    var redAlertMinutes: Int // Time in minutes for red alert (urgent)
    var blueAlertMinutes: Int // Time in minutes for blue alert (approaching)
    var refreshInterval: Int // Time in seconds for refresh interval
    
    static let defaultPreferences = StationPreferences(
        fromStation: "3700",
        toStation: "2300",
        upcomingItemsCount: 3,
        launchAtLogin: false,
        redAlertMinutes: 15,
        blueAlertMinutes: 30,
        refreshInterval: 300
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
                         launchAtLogin: Bool = false, redAlertMinutes: Int = 15, blueAlertMinutes: Int = 30,
                         refreshInterval: Int = 300) {
        preferences = StationPreferences(
            fromStation: fromStation, 
            toStation: toStation, 
            upcomingItemsCount: upcomingItemsCount, 
            launchAtLogin: launchAtLogin,
            redAlertMinutes: redAlertMinutes,
            blueAlertMinutes: blueAlertMinutes,
            refreshInterval: refreshInterval
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
}
