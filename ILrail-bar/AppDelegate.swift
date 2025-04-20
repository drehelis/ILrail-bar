import SwiftUI
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var trainScheduleTimer: Timer?
    private let networkManager = NetworkManager()
    private var preferencesWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var eventMonitor: EventMonitor?
    
    // Current train schedules and error state
    private var currentTrainSchedules: [TrainSchedule] = []
    private var currentErrorMessage: String?
    private var isRefreshing: Bool = false
    
    private enum Constants {
        static let aboutTitle = "ILrail-bar"
        static let menuBarErrorText = " Error"
        static let menuBarNoResultsText = " No trains"
        static let noTrainFoundMessage = "No trains found for route"
    }
        
    private func createAndShowWindow(
        size: NSSize,
        title: String,
        styleMask: NSWindow.StyleMask,
        center: Bool = false,
        view: NSView,
        storeIn windowRef: inout NSWindow?
    ) {
        // If a window already exists, just bring it to front
        if let window = windowRef {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        
        // Set self as the window delegate to handle close events
        window.delegate = self
        
        // Set the content view
        window.contentView = view
        
        // Store reference to prevent deallocation
        windowRef = window
        
        // Make the window visible and active
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        logDebug("\(title) window created and should be visible now")
    }
    
    // This method is called before applicationDidFinishLaunching
    func applicationWillFinishLaunching(_ notification: Notification) {
        // LSUIElement is properly set in Info.plist, no need to explicitly set activation policy
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Fetch station data as soon as the app starts
        fetchStationData()
        
        // Initialize popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        
        setupStatusItem()
        fetchTrainSchedule()
        
        trainScheduleTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(PreferencesManager.shared.preferences.refreshInterval),
            target: self,
            selector: #selector(timerRefresh),
            userInfo: nil,
            repeats: true
        )
        
        // Listen for preferences changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPreferencesChanged),
            name: .reloadPreferencesChanged,
            object: nil
        )
        
        // Setup event monitor to close popover when clicking outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.closePopover()
            }
        }
        eventMonitor?.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stop()
    }
    
    @objc private func timerRefresh() {
        let interval = PreferencesManager.shared.preferences.refreshInterval
        logInfo("Performing scheduled refresh (interval: \(interval) seconds)")
        fetchTrainSchedule(showLoading: false)
    }
    
    private func fetchStationData() {
        Station.fetchStations { stations in
            DispatchQueue.main.async {
                if let stations = stations {
                    // Update the stations
                    Station.setStations(stations)
                    
                    // Notify that stations have been loaded
                    NotificationCenter.default.post(name: .stationsLoaded, object: nil)

                } else {
                    logWarning("Failed to load stations, using default stations")
                }
            }
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use a train icon with better styling
            let tramImage = NSImage(systemSymbolName: "tram.fill", accessibilityDescription: "Train")
            tramImage?.isTemplate = true  // Ensures proper appearance in dark/light modes
            button.image = tramImage
            // Add action to show popover
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        if let button = statusItem.button {
            updatePopoverContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func closePopover() {
        popover.performClose(nil)
    }
    
    private func updatePopoverContent() {
        if !currentTrainSchedules.isEmpty {
            // Get station names
            let preferences = PreferencesManager.shared.preferences
            let stations = Station.allStations
            
            // Find station names from the Station class based on preferences
            let fromStation = stations.first(where: { $0.id == preferences.fromStation })
            let toStation = stations.first(where: { $0.id == preferences.toStation })
            
            // Use the found station names, or fall back to the IDs if not found
            let fromStationName = fromStation?.name ?? preferences.fromStation
            let toStationName = toStation?.name ?? preferences.toStation
            
            // Create the train popover view
            let trainView = TrainPopoverView(
                trainSchedules: currentTrainSchedules,
                fromStationName: fromStationName,
                toStationName: toStationName,
                preferences: preferences,
                isRefreshing: isRefreshing,
                onReverseDirection: { [weak self] in
                    self?.reverseTrainDirection()
                },
                onRefresh: { [weak self] in
                    self?.manualRefresh()
                },
                onPreferences: { [weak self] in
                    self?.showPreferences()
                },
                onWebsite: { [weak self] in
                    self?.openRailWebsite()
                },
                onAbout: { [weak self] in
                    self?.showAbout()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
            
            popover.contentViewController = NSHostingController(rootView: trainView)
        } else if let errorMessage = currentErrorMessage {
            // Get station names
            let preferences = PreferencesManager.shared.preferences
            let stations = Station.allStations
            
            // Find station names from the Station class based on preferences
            let fromStation = stations.first(where: { $0.id == preferences.fromStation })
            let toStation = stations.first(where: { $0.id == preferences.toStation })
            
            // Use the found station names, or fall back to the IDs if not found
            let fromStationName = fromStation?.name ?? preferences.fromStation
            let toStationName = toStation?.name ?? preferences.toStation
            
            // Create the error popover view
            let errorView = ErrorPopoverView(
                errorMessage: errorMessage,
                fromStationName: fromStationName,
                toStationName: toStationName,
                isRefreshing: isRefreshing,
                onReverseDirection: { [weak self] in
                    self?.reverseTrainDirection()
                },
                onRefresh: { [weak self] in
                    self?.manualRefresh()
                },
                onPreferences: { [weak self] in
                    self?.showPreferences()
                },
                onWebsite: { [weak self] in
                    self?.openRailWebsite()
                },
                onAbout: { [weak self] in
                    self?.showAbout()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
            
            popover.contentViewController = NSHostingController(rootView: errorView)
        }
    }
    
    @objc func showPreferences(_ sender: Any? = nil) {
        closePopover()
        
        // Create a new hosting view with an instance of PreferencesView
        // Pass nil for the window as we'll set it properly after creating it
        let preferencesView = PreferencesView()
        let hostingView = NSHostingView(rootView: preferencesView)
        
        createAndShowWindow(
            size: NSSize(width: 400, height: 350),
            title: "Preferences",
            styleMask: [.titled, .closable, .miniaturizable],
            view: hostingView,
            storeIn: &preferencesWindow
        )
        
        // Now update the view with the correct window reference if needed
        if let window = preferencesWindow {
            // Access the underlying PreferencesView and update its window property
            let updatedView = PreferencesView(window: window)
            hostingView.rootView = updatedView
        }
    }
    
    @objc private func reloadPreferencesChanged() {
        fetchTrainSchedule()
        
        // Update the refresh timer with new interval
        if let existingTimer = trainScheduleTimer {
            existingTimer.invalidate()
        }
        
        // Create new timer with updated interval from preferences
        trainScheduleTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(PreferencesManager.shared.preferences.refreshInterval),
            target: self,
            selector: #selector(timerRefresh),
            userInfo: nil,
            repeats: true
        )
    }
    
    @objc private func fetchTrainSchedule(showLoading: Bool = true) {
        // Set the refresh state if we want to show loading
        if showLoading {
            isRefreshing = true
            
            // Update popover content if it's visible to show the loading state
            if popover.isShown {
                updatePopoverContent()
            }
        }
        networkManager.fetchTrainSchedule { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Reset refresh state
                self.isRefreshing = false
                
                switch result {
                case .success(let trainSchedules):
                    if (!trainSchedules.isEmpty) {
                        // Store train schedules
                        self.currentTrainSchedules = trainSchedules
                        self.currentErrorMessage = nil
                        self.updateStatusBarWithTrain(trainSchedules[0])
                        
                        // Update popover content if it's visible
                        if self.popover.isShown {
                            self.updatePopoverContent()
                        }
                    } else {
                        self.currentTrainSchedules = []
                        self.currentErrorMessage = Constants.noTrainFoundMessage
                        self.updateStatusBarWithError(Constants.noTrainFoundMessage)
                        
                        // Update popover content if it's visible
                        if self.popover.isShown {
                            self.updatePopoverContent()
                        }
                    }
                case .failure(let error):
                    self.currentTrainSchedules = []
                    self.currentErrorMessage = error.localizedDescription
                    self.updateStatusBarWithError(error.localizedDescription)
                    
                    // Update popover content if it's visible
                    if self.popover.isShown {
                        self.updatePopoverContent()
                    }
                }
            }
        }
    }
    
    @objc private func manualRefresh() {
        logInfo("Refresh request by user")
        
        // Set refresh state immediately to update the UI
        isRefreshing = true
        
        // Update the popover UI to show loading state
        if popover.isShown {
            updatePopoverContent()
        }
        
        // small delay allows the animation to be visible to the user
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchTrainSchedule(showLoading: false)
        }
    }
    
    private func updateStatusBarWithTrain(_ train: TrainSchedule) {
        if let button = statusItem.button {
            let departureTimeString = DateFormatters.timeFormatter.string(from: train.departureTime)
            
            let timeUntilDepartureSeconds = train.departureTime.timeIntervalSinceNow
            let timeUntilDepartureMinutes = timeUntilDepartureSeconds / 60
            logDebug("Time until departure: \(timeUntilDepartureMinutes) minutes")
            
            let preferences = PreferencesManager.shared.preferences
            let redTimeUntilDeparture = TimeInterval(preferences.redAlertMinutes * 60)
            let blueTimeUntilDeparture = TimeInterval(preferences.blueAlertMinutes * 60)
            
            if timeUntilDepartureSeconds <= redTimeUntilDeparture {
                button.attributedTitle = NSAttributedString(
                    string: " " + departureTimeString,
                    attributes: [NSAttributedString.Key.foregroundColor: NSColor.systemRed]
                )
            } else if timeUntilDepartureSeconds <= blueTimeUntilDeparture {
                button.attributedTitle = NSAttributedString(
                    string: " " + departureTimeString,
                    attributes: [NSAttributedString.Key.foregroundColor: NSColor.systemBlue]
                )
            } else {
                button.attributedTitle = NSAttributedString(
                    string: " " + departureTimeString,
                    attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor]
                )
            }
        }
    }
    
    private func updateStatusBarWithError(_ message: String) {
        if let button = statusItem.button {
            let menubarText = message == Constants.noTrainFoundMessage ? Constants.menuBarNoResultsText : Constants.menuBarErrorText
            let textColor = message == Constants.noTrainFoundMessage ? NSColor.labelColor : NSColor.systemRed
            
            button.attributedTitle = NSAttributedString(
                string: menubarText,
                attributes: [NSAttributedString.Key.foregroundColor: textColor]
            )
        }
    }
        
    @objc func showAbout(_ sender: Any? = nil) {
        closePopover()
        
        let aboutView = AboutView(window: aboutWindow ?? NSWindow())
        let hostingView = NSHostingView(rootView: aboutView)
        createAndShowWindow(
            size: NSSize(width: 350, height: 350),
            title: Constants.aboutTitle,
            styleMask: [.titled, .closable],
            center: true,
            view: hostingView,
            storeIn: &aboutWindow
        )
    }
    
    @objc private func openRailWebsite(_ sender: Any? = nil) {
        closePopover()
        
        let preferences = PreferencesManager.shared.preferences
        let currentDate = Date()
        let currentDateStr = DateFormatters.dateFormatter.string(from: currentDate)
        
        // Use DateFormatters.timeFormatter to get the time string
        let timeStr = DateFormatters.timeFormatter.string(from: currentDate)
        
        // Extract hours and minutes from the formatted time string using tuple pattern matching
        let components = timeStr.split(separator: ":")
        let (hours, minutes) = (String(components[0]), String(components[1]))
        
        let officialSiteUrl = URL(string: "https://www.rail.co.il/?" +
                                 "page=routePlanSearchResults" +
                                 "&fromStation=\(preferences.fromStation)" +
                                 "&toStation=\(preferences.toStation)" +
                                 "&date=\(currentDateStr)" +
                                 "&hours=\(hours)" +
                                 "&minutes=\(minutes)" +
                                 "&scheduleType=1"
                               )
        
        if let url = officialSiteUrl {
            NSWorkspace.shared.open(url)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        // If our preferences window is closing, clear the reference
        if let closingWindow = notification.object as? NSWindow,
           closingWindow === preferencesWindow {
            // Ensure the window is completely released
            preferencesWindow = nil
        }
        
        // If our about window is closing, clear the reference
        if let closingWindow = notification.object as? NSWindow,
           closingWindow === aboutWindow {
            // Ensure the window is completely released
            aboutWindow = nil
        }
    }

    private func reverseTrainDirection() {
        let preferences = PreferencesManager.shared.preferences
        
        let oldFromStation = preferences.fromStation
        let oldToStation = preferences.toStation
        
        logInfo("Reversing train direction: \(oldFromStation) ↔ \(oldToStation)")
        
        PreferencesManager.shared.savePreferences(
            fromStation: oldToStation,
            toStation: oldFromStation,
            upcomingItemsCount: preferences.upcomingItemsCount,
            launchAtLogin: preferences.launchAtLogin,
            redAlertMinutes: preferences.redAlertMinutes,
            blueAlertMinutes: preferences.blueAlertMinutes,
            refreshInterval: preferences.refreshInterval
        )
        
        // Trigger a refresh to update the train schedule
        NotificationCenter.default.post(name: .reloadPreferencesChanged, object: nil)
    }
}

// Event monitor to detect clicks outside the popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
