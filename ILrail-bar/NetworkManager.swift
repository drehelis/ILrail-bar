import Cocoa
import Foundation

class NetworkManager {
    static let shared = NetworkManager()

    private let githubApiURL = "https://api.github.com/repos/drehelis/ilrail-bar/releases/latest"

    // Official API URLs (primary)
    private let originalApiKey = "5e64d66cf03f4547bcac5de2de06b566"
    private let originalApiBaseURL = "https://rail-api.rail.co.il"
    private var originalTimetableBaseURL: String {
        return originalApiBaseURL + "/rjpa/api/v1/timetable/searchTrainLuzForDateTime"
    }
    private var originalStationsBaseURL: String {
        return originalApiBaseURL + "/common/api/v1/stations"
    }

    // Proxy URLs (fallback)
    private let proxyApiBaseURL = "https://ilrail-bar-proxy-bmt2z7lcca-zf.a.run.app"
    private var proxyTimetableBaseURL: String {
        return proxyApiBaseURL + "/timetable"
    }
    private var proxyStationsBaseURL: String { return proxyApiBaseURL + "/stations" }

    private let madeUpUserAgent = "ILrail-bar/1.0 macOS"

    private let languageId = "Hebrew"
    private let scheduleType = "1"
    private let systemType = "2"

    enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
        case cacheError
    }

    private struct CacheKeys {
        static let stationsData = "cachedStationsData"
        static let timetablePrefix = "cachedTimetableData_"
    }

    // Generic cache manager function
    // Stored in ~/Library/Containers/il.co.liar.ILrail-bar/Data/Library/Preferences/il.co.liar.ILrail-bar.plist
    private func cacheData(_ data: Data, forKey key: String) {
        let cacheBundle: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "data": data,
        ]
        UserDefaults.standard.set(cacheBundle, forKey: key)
        logDebug("Data cached successfully with key: \(key)")
    }

    // Generic cache retrieval function
    private func getCachedData(forKey key: String) -> (data: Data, ageInMinutes: Int)? {
        if let cachedBundle = UserDefaults.standard.dictionary(forKey: key),
            let cachedData = cachedBundle["data"] as? Data,
            let timestamp = cachedBundle["timestamp"] as? TimeInterval
        {
            let cacheAge = Date().timeIntervalSince1970 - timestamp
            let minutes = Int(cacheAge / 60)
            return (cachedData, minutes)
        }
        return nil
    }

    // Check if cached data is still valid based on refresh interval
    private func isCacheValid(ageInMinutes: Int, refreshIntervalSeconds: Int) -> Bool {
        return ageInMinutes < (refreshIntervalSeconds / 60)
    }

    // Function to get timetable cache key
    private func getTimetableCacheKey(fromStation: String, toStation: String) -> String {
        return "\(CacheKeys.timetablePrefix)\(fromStation)_\(toStation)"
    }

    // Helper method to create request with appropriate headers
    private func createRequest(url: URL, useApiKey: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue(madeUpUserAgent, forHTTPHeaderField: "User-Agent")
        if useApiKey {
            request.addValue(originalApiKey, forHTTPHeaderField: "ocp-apim-subscription-key")
        }
        return request
    }

    func fetchStations(completion: @escaping (Result<[RemoteStation], NetworkError>) -> Void) {
        let queryItems = [
            URLQueryItem(name: "languageId", value: "English"),
            URLQueryItem(name: "systemType", value: systemType),
        ]

        // Try official API first
        performSingleStationsRequest(
            baseURL: originalStationsBaseURL,
            queryItems: queryItems,
            useApiKey: true
        ) { [weak self] result in
            switch result {
            case .success(let stations):
                logInfo("Successfully fetched stations from official API")
                completion(.success(stations))

            case .failure(let error):
                logWarning(
                    "Official API failed: \(error.localizedDescription). Trying proxy fallback...")
                self?.tryProxyStationsAPI(
                    queryItems: queryItems, officialError: error, completion: completion)
            }
        }
    }

    private func tryProxyStationsAPI(
        queryItems: [URLQueryItem],
        officialError: NetworkError,
        completion: @escaping (Result<[RemoteStation], NetworkError>) -> Void
    ) {
        performSingleStationsRequest(
            baseURL: proxyStationsBaseURL,
            queryItems: queryItems,
            useApiKey: false
        ) { [weak self] fallbackResult in
            switch fallbackResult {
            case .success(let stations):
                logInfo("Successfully fetched stations from proxy API (fallback)")
                completion(.success(stations))

            case .failure(let fallbackError):
                logError(
                    "Both APIs failed. Official: \(officialError.localizedDescription), Proxy: \(fallbackError.localizedDescription)"
                )
                self?.tryStationsCache(completion: completion, fallbackError: fallbackError)
            }
        }
    }

    private func tryStationsCache(
        completion: @escaping (Result<[RemoteStation], NetworkError>) -> Void,
        fallbackError: NetworkError
    ) {
        guard let cachedDataInfo = getCachedData(forKey: CacheKeys.stationsData) else {
            completion(.failure(fallbackError))
            return
        }

        do {
            let response = try JSONDecoder().decode(StationResponse.self, from: cachedDataInfo.data)
            logInfo(
                "Using cached stations from \(cachedDataInfo.ageInMinutes) minutes ago as last resort"
            )
            completion(.success(response.result))
        } catch {
            logError("Cached data is also invalid: \(error.localizedDescription)")
            completion(.failure(.cacheError))
        }
    }

    private func performSingleStationsRequest(
        baseURL: String,
        queryItems: [URLQueryItem],
        useApiKey: Bool,
        completion: @escaping (Result<[RemoteStation], NetworkError>) -> Void
    ) {
        guard var components = URLComponents(string: baseURL) else {
            completion(.failure(.invalidURL))
            return
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }

        let request = createRequest(url: url, useApiKey: useApiKey)
        logInfo("Making network request to: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.serverError(error.localizedDescription)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
                !(200...299).contains(httpResponse.statusCode)
            {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                completion(.failure(.serverError(errorMessage)))
                return
            }

            do {
                let response = try JSONDecoder().decode(StationResponse.self, from: data)
                // Cache the data for future use
                self?.cacheData(data, forKey: CacheKeys.stationsData)
                completion(.success(response.result))
            } catch {
                logError("Error decoding stations: \(error.localizedDescription)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }

    func fetchTrainSchedule(completion: @escaping (Result<[TrainSchedule], Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: Date())

        let preferences = PreferencesManager.shared.preferences

        // Determine which stations to use based on the direction flag
        let fromStationId =
            preferences.isDirectionReversed ? preferences.toStation : preferences.fromStation
        let toStationId =
            preferences.isDirectionReversed ? preferences.fromStation : preferences.toStation

        // Generate a cache key based on actual from/to stations used
        let cacheKey = getTimetableCacheKey(fromStation: fromStationId, toStation: toStationId)

        // Create a function to process API response data
        let processTrainData: (Data) throws -> [TrainSchedule] = { data in
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

                    if let date = DateFormatters.parseDateFormats(dateString) {
                        return date
                    }

                    // If we reach here, none of our formats worked
                    logWarning("Failed to parse date string: \(dateString)")

                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription:
                                "Date string does not match any expected format: \(dateString)")
                    )
                }

                let response = try decoder.decode(APIResponse.self, from: data)
                let now = Date()
                var trainSchedules: [TrainSchedule] = []

                for travel in response.result.travels {
                    // The number of changes is the number of trains in this travel minus 1
                    // If there's just one train, there are 0 changes
                    let trainChanges = travel.trains.count - 1

                    // For multi-train journeys, we only need to add the first train segment
                    // with information about the entire journey
                    if let firstTrainData = travel.trains.first {
                        let trainNumberString = String(describing: firstTrainData.trainNumber)
                        let allTrainNumbers = travel.trains.map {
                            String(describing: $0.trainNumber)
                        }

                        // For the platforms list, always use originPlatform values for consistent display
                        let allPlatforms = travel.trains.map { String($0.originPlatform) }
                        let platformToShow = String(firstTrainData.originPlatform)

                        // We want to show the first train of each travel, with the overall journey time
                        // Instead of checking that both stations match, we'll check the overall journey details
                        // This handles train changes correctly
                        let schedule = TrainSchedule(
                            trainNumber: trainNumberString,
                            departureTime: firstTrainData.departureTime,
                            arrivalTime: travel.trains.last?.arrivalTime
                                ?? firstTrainData.arrivalTime,  // Use the final arrival time for the complete journey
                            platform: platformToShow,
                            fromStationName: firstTrainData.fromStationName
                                ?? preferences.fromStation,
                            toStationName: travel.trains.last?.toStationName ?? firstTrainData
                                .toStationName ?? preferences.toStation,
                            trainChanges: trainChanges,
                            allTrainNumbers: allTrainNumbers,
                            allPlatforms: allPlatforms
                        )
                        trainSchedules.append(schedule)
                    }
                }

                // Filter out trains that have already departed with 1-minute buffer
                // Also filter out trains that would depart before the user can walk to the station
                // And filter out trains with more changes than the max allowed
                let walkTimeDurationSec = TimeInterval(preferences.walkTimeDurationMin * 60)
                let upcomingTrains = trainSchedules.filter {
                    // First check if this train has too many changes
                    if preferences.maxTrainChanges != -1
                        && $0.trainChanges > preferences.maxTrainChanges
                    {
                        return false
                    }

                    // Then check if the train is still relevant based on timing
                    let timeUntilDeparture = $0.departureTime.timeIntervalSince(now)
                    if preferences.walkTimeDurationMin > 0 {
                        return timeUntilDeparture > walkTimeDurationSec
                    } else {
                        return timeUntilDeparture > -60  // Allow trains departing within the last minute
                    }
                }

                // Sort the filtered trains by departure time
                let sortedTrains = upcomingTrains.sorted { $0.departureTime < $1.departureTime }

                return sortedTrains
            } catch {
                logError("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        }

        // First check the cache
        if let cachedDataInfo = getCachedData(forKey: cacheKey) {
            let cacheAgeInMinutes = cachedDataInfo.ageInMinutes
            let refreshIntervalSeconds = preferences.refreshInterval

            // Check if cache is still valid based on the refresh interval
            if isCacheValid(
                ageInMinutes: cacheAgeInMinutes, refreshIntervalSeconds: refreshIntervalSeconds)
            {
                do {
                    let cachedTrains = try processTrainData(cachedDataInfo.data)
                    logInfo(
                        "Using cached timetable data from \(cacheAgeInMinutes) minutes ago (within refresh interval)"
                    )
                    completion(.success(cachedTrains))
                    return  // Exit early as we're using cache
                } catch {
                    logWarning(
                        "Error processing cached data: \(error.localizedDescription). Will fetch fresh data."
                    )
                    // Continue to network fetch below if cache processing fails
                }
            } else {
                logInfo(
                    "Cache is \(cacheAgeInMinutes) minutes old, which exceeds refresh interval (\(refreshIntervalSeconds) seconds). Fetching fresh data."
                )
                // Continue to network fetch below as cache is too old
            }
        } else {
            logInfo("No cache found. Fetching fresh data.")
            // Continue to network fetch below as there's no cache
        }

        // If we reached here, we need to fetch from the network
        logInfo("Fetching trains from \(preferences.fromStation) to \(preferences.toStation)")

        let queryItems = [
            URLQueryItem(name: "fromStation", value: fromStationId),
            URLQueryItem(name: "toStation", value: toStationId),
            URLQueryItem(name: "date", value: currentDate),
            URLQueryItem(name: "hour", value: currentTime),
            URLQueryItem(name: "scheduleType", value: scheduleType),
            URLQueryItem(name: "systemType", value: systemType),
            URLQueryItem(name: "languageId", value: languageId),
        ]

        // Try official API first
        performSingleTrainScheduleRequest(
            baseURL: originalTimetableBaseURL,
            queryItems: queryItems,
            useApiKey: true,
            cacheKey: cacheKey,
            processData: processTrainData
        ) { [weak self] result in
            switch result {
            case .success(let trains):
                logInfo("Successfully fetched train schedule from official API")
                completion(.success(trains))

            case .failure(let error):
                logWarning(
                    "Official API failed: \(error.localizedDescription). Trying proxy fallback...")
                self?.tryProxyTrainScheduleAPI(
                    queryItems: queryItems,
                    cacheKey: cacheKey,
                    processData: processTrainData,
                    officialError: error,
                    completion: completion
                )
            }
        }
    }

    private func tryProxyTrainScheduleAPI(
        queryItems: [URLQueryItem],
        cacheKey: String,
        processData: @escaping (Data) throws -> [TrainSchedule],
        officialError: Error,
        completion: @escaping (Result<[TrainSchedule], Error>) -> Void
    ) {
        performSingleTrainScheduleRequest(
            baseURL: proxyTimetableBaseURL,
            queryItems: queryItems,
            useApiKey: false,
            cacheKey: cacheKey,
            processData: processData
        ) { [weak self] fallbackResult in
            switch fallbackResult {
            case .success(let trains):
                logInfo("Successfully fetched train schedule from proxy API (fallback)")
                completion(.success(trains))

            case .failure(let fallbackError):
                logError(
                    "Both APIs failed. Official: \(officialError.localizedDescription), Proxy: \(fallbackError.localizedDescription)"
                )
                self?.tryTrainScheduleCache(
                    cacheKey: cacheKey,
                    processData: processData,
                    completion: completion,
                    fallbackError: fallbackError
                )
            }
        }
    }

    private func tryTrainScheduleCache(
        cacheKey: String,
        processData: @escaping (Data) throws -> [TrainSchedule],
        completion: @escaping (Result<[TrainSchedule], Error>) -> Void,
        fallbackError: Error
    ) {
        guard let cachedDataInfo = getCachedData(forKey: cacheKey) else {
            completion(.failure(fallbackError))
            return
        }

        do {
            let cachedTrains = try processData(cachedDataInfo.data)
            logInfo(
                "Using cached train schedule from \(cachedDataInfo.ageInMinutes) minutes ago as last resort"
            )
            completion(.success(cachedTrains))
        } catch {
            logError("Cached data is also invalid: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    private func performSingleTrainScheduleRequest(
        baseURL: String,
        queryItems: [URLQueryItem],
        useApiKey: Bool,
        cacheKey: String,
        processData: @escaping (Data) throws -> [TrainSchedule],
        completion: @escaping (Result<[TrainSchedule], Error>) -> Void
    ) {
        guard var components = URLComponents(string: baseURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let request = createRequest(url: url, useApiKey: useApiKey)
        logInfo("Making network request to: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
                !(200...299).contains(httpResponse.statusCode)
            {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                completion(.failure(NetworkError.serverError(errorMessage)))
                return
            }

            do {
                let trains = try processData(data)
                // Cache the data for future use
                self?.cacheData(data, forKey: cacheKey)
                completion(.success(trains))
            } catch {
                logError("Error processing train schedule: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    func checkForUpdates(completion: @escaping (Result<Bool, NetworkError>) -> Void) {

        guard let url = URL(string: githubApiURL) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.addValue(madeUpUserAgent, forHTTPHeaderField: "User-Agent")

        logInfo("Checking for updates at: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                logError("Error checking for updates: \(error.localizedDescription)")
                completion(.failure(.serverError(error.localizedDescription)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.name
                let currentVersion = self.getCurrentAppVersion()

                logInfo("Current version: \(currentVersion), Latest version: \(latestVersion)")

                let hasUpdate = self.isVersionNewer(latest: latestVersion, current: currentVersion)
                completion(.success(hasUpdate))
            } catch {
                logError("Error decoding GitHub release response: \(error.localizedDescription)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }

    private func getCurrentAppVersion() -> String {
        var version: String = "x.x.x"

        if Thread.isMainThread {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                version = appDelegate.getAppVersion()
            }
        } else {
            DispatchQueue.main.sync {
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    version = appDelegate.getAppVersion()
                }
            }
        }

        return version
    }

    private func isVersionNewer(latest: String, current: String) -> Bool {
        // Remove 'v' prefix if present
        let latestVersion = latest.hasPrefix("v") ? String(latest.dropFirst()) : latest
        let currentVersion = current.hasPrefix("v") ? String(current.dropFirst()) : current

        // Compare versions using semantic versioning
        let latestComponents = latestVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }

        // Ensure both arrays have at least 3 components (major.minor.patch)
        let latestPadded =
            latestComponents + Array(repeating: 0, count: max(0, 3 - latestComponents.count))
        let currentPadded =
            currentComponents + Array(repeating: 0, count: max(0, 3 - currentComponents.count))

        // Compare each component
        for i in 0..<max(latestPadded.count, currentPadded.count) {
            let latestPart = i < latestPadded.count ? latestPadded[i] : 0
            let currentPart = i < currentPadded.count ? currentPadded[i] : 0

            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }

        return false  // Versions are equal
    }
}
