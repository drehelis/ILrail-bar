import Foundation
import Combine

class PopoverState: ObservableObject {
    @Published var trainSchedules: [TrainSchedule] = []
    @Published var errorMessage: String? = nil
    @Published var isRefreshing: Bool = false
    @Published var fromStationName: String = ""
    @Published var toStationName: String = ""

    // Store the whole preferences object but expose specific properties to avoid nested observation issues
    var preferences: StationPreferences = PreferencesManager.shared.preferences {
        didSet {
            objectWillChange.send()
        }
    }

    // Callbacks to AppDelegate for system-level operations
    var onRefresh: (() -> Void)?
    var onReverseDirection: (() -> Void)?
    var onPreferences: (() -> Void)?
    var onWebsite: (() -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onSelectFavoriteRoute: ((String) -> Void)?

    // Computed properties
    var hasTrains: Bool {
        !trainSchedules.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil && trainSchedules.isEmpty
    }

    // User-facing action methods
    func refresh() {
        onRefresh?()
    }

    func reverseDirection() {
        onReverseDirection?()
    }

    func showPreferences() {
        onPreferences?()
    }

    func openWebsite() {
        onWebsite?()
    }

    func showAbout() {
        onAbout?()
    }

    func quit() {
        onQuit?()
    }

    func selectFavoriteRoute(_ routeId: String) {
        onSelectFavoriteRoute?(routeId)
    }
}
