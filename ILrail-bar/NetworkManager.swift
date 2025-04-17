import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let apiKey = "4b0d355121fe4e0bb3d86e902efe9f20"
    private let apiBaseURL = "https://israelrail.azurefd.net"    
    private var timetableBaseURL: String { return apiBaseURL + "/rjpa-prod/api/v1/timetable/searchTrainLuzForDateTime" }
    private var stationsBaseURL: String { return apiBaseURL + "/common/api/v1/stations" }
    private let madeUpUserAgent = "ILrail-bar/1.0 macOS"
    
    private let languageId = "Hebrew"
    private let scheduleType = "1"
    private let systemType = "2"
    
    enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
    }
    
    func fetchStations(completion: @escaping (Result<[RemoteStation], NetworkError>) -> Void) {
        guard var components = URLComponents(string: stationsBaseURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        components.queryItems = [
            URLQueryItem(name: "languageId", value: "English"),
            URLQueryItem(name: "systemType", value: systemType)
        ]
        
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(madeUpUserAgent, forHTTPHeaderField: "User-Agent")
        request.addValue(apiKey, forHTTPHeaderField: "ocp-apim-subscription-key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                logError("Error fetching stations: \(error.localizedDescription)")
                completion(.failure(.serverError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                completion(.failure(.serverError(errorMessage)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(StationResponse.self, from: data)
                
                // Cache the data for future use
                UserDefaults.standard.set(data, forKey: "cachedStationsData")
                
                completion(.success(response.result))
            } catch {
                logError("Error decoding stations: \(error.localizedDescription)")
                
                // Try to decode the structure of the JSON to understand the format
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        logDebug("JSON is a dictionary with keys: \(json.keys)")
                    } else if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        logDebug("JSON is an array of dictionaries with \(json.count) items")
                    } else {
                        logDebug("JSON is in an unknown format")
                    }
                } catch {
                    logError("Failed to parse JSON: \(error.localizedDescription)")
                }
                
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
        
        logInfo("Fetching trains from \(preferences.fromStation) to \(preferences.toStation)")
        
        var components = URLComponents(string: timetableBaseURL)
        components?.queryItems = [
            URLQueryItem(name: "fromStation", value: preferences.fromStation),
            URLQueryItem(name: "toStation", value: preferences.toStation),
            URLQueryItem(name: "date", value: currentDate),
            URLQueryItem(name: "hour", value: currentTime),
            URLQueryItem(name: "scheduleType", value: scheduleType),
            URLQueryItem(name: "systemType", value: systemType),
            URLQueryItem(name: "languageId", value: languageId)
        ]
        
        guard let url = components?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(madeUpUserAgent, forHTTPHeaderField: "User-Agent")
        request.addValue(apiKey, forHTTPHeaderField: "ocp-apim-subscription-key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                completion(.failure(NetworkError.serverError(errorMessage)))
                return
            }
            
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
                        DecodingError.Context(codingPath: decoder.codingPath,
                                              debugDescription: "Date string does not match any expected format: \(dateString)")
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
                        let allTrainNumbers = travel.trains.map { String(describing: $0.trainNumber) }
                        
                        // We want to show the first train of each travel, with the overall journey time
                        // Instead of checking that both stations match, we'll check the overall journey details
                        // This handles train changes correctly
                        let schedule = TrainSchedule(
                            trainNumber: trainNumberString,
                            departureTime: firstTrainData.departureTime,
                            arrivalTime: travel.trains.last?.arrivalTime ?? firstTrainData.arrivalTime, // Use the final arrival time for the complete journey
                            platform: firstTrainData.platform,
                            fromStationName: firstTrainData.fromStationName ?? preferences.fromStation,
                            toStationName: travel.trains.last?.toStationName ?? firstTrainData.toStationName ?? preferences.toStation,
                            trainChanges: trainChanges,
                            allTrainNumbers: allTrainNumbers
                        )
                        trainSchedules.append(schedule)
                        
                        logDebug("Adding journey with \(trainChanges) switches: Train #\(trainNumberString) from \(firstTrainData.fromStationName ?? "unknown") to \(travel.trains.last?.toStationName ?? "unknown")")
                    }
                }
                
                               
                // Filter out trains that have already departed with 1-minute buffer
                // Sometimes API time and local time can be slightly off
                let upcomingTrains = trainSchedules.filter { 
                    $0.departureTime.timeIntervalSince(now) > -60 // Allow trains departing within the last minute
                }
                
                // Sort the filtered trains by departure time
                let sortedTrains = upcomingTrains.sorted { $0.departureTime < $1.departureTime }
                
                logDebug("Sorted upcoming trains:")
                for (_, train) in sortedTrains.enumerated() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let departureString = formatter.string(from: train.departureTime)
                    logDebug("Train #\(train.trainNumber): from: \(train.fromStationName), to: \(train.toStationName), departs at \(departureString)")
                }
                
                completion(.success(sortedTrains))
            } catch {
                logError("Decoding error: \(error)")
                completion(.failure(NetworkError.decodingError))
            }
        }.resume()
    }
}