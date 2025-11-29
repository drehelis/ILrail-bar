import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var preferencesPopover: NSPopover!
    private var trainScheduleTimer: Timer?
    private var activeScheduleTimer: Timer?
    private var displayUpdateTimer: Timer?
    private var updateCheckTimer: Timer?
    private let networkManager = NetworkManager()
    private var preferencesWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var eventMonitor: EventMonitor?
    private var preferencesEventMonitor: EventMonitor?
    private var isMenuBarVisible: Bool = true
    private var hasUpdateAvailable: Bool = false

    // Popover state - single source of truth
    private var popoverState = PopoverState()

    private enum Constants {
        static let appVersion: String = "%%VERSION%%"
        static let aboutTitle = "ILrail-bar \(appVersion)"
        static let menuBarErrorText = "Error"
        static let menuBarNoResultsText = "No trains"
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

        // Setup PopoverState callbacks
        popoverState.onRefresh = { [weak self] in
            self?.manualRefresh()
        }
        popoverState.onReverseDirection = { [weak self] in
            self?.reverseTrainDirection()
        }
        popoverState.onPreferences = { [weak self] in
            self?.showPreferences()
        }
        popoverState.onWebsite = { [weak self] in
            self?.openRailWebsite()
        }
        popoverState.onAbout = { [weak self] in
            self?.showAbout()
        }
        popoverState.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        popoverState.onSelectFavoriteRoute = { [weak self] routeId in
            self?.selectFavoriteRoute(routeId)
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self

        // Create the popover view ONCE with state - it will update reactively
        let popoverView = TrainPopoverView(state: popoverState)
        popover.contentViewController = NSHostingController(rootView: popoverView)

        preferencesPopover = NSPopover()
        preferencesPopover.behavior = .transient
        preferencesPopover.delegate = self

        setupStatusItem()
        fetchTrainSchedule()

        trainScheduleTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(PreferencesManager.shared.preferences.refreshInterval),
            target: self,
            selector: #selector(timerRefresh),
            userInfo: nil,
            repeats: true
        )

        activeScheduleTimer = Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(checkActiveHours),
            userInfo: nil,
            repeats: true
        )

        displayUpdateTimer = Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(updateDisplayWithoutFetching),
            userInfo: nil,
            repeats: true
        )

        // Configure update checking timer
        configureUpdateCheckTimer()

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

        // Setup event monitor for preferences popover
        preferencesEventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            if let self = self, self.preferencesPopover.isShown {
                self.closePreferencesPopover()
            }
        }
        preferencesEventMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stop()
        preferencesEventMonitor?.stop()

        // Invalidate all timers when the app terminates
        trainScheduleTimer?.invalidate()
        activeScheduleTimer?.invalidate()
        displayUpdateTimer?.invalidate()
        updateCheckTimer?.invalidate()
    }

    @objc private func timerRefresh() {
        let interval = PreferencesManager.shared.preferences.refreshInterval
        logInfo("Performing scheduled refresh (interval: \(interval) seconds)")
        fetchTrainSchedule(showLoading: false)
    }

    @objc private func checkActiveHours() {
        let isActive = isCurrentTimeActive()
        if isActive && !isMenuBarVisible {
            logInfo("Activating train time display")
            isMenuBarVisible = true

            // Update with the latest train info if available
            if !popoverState.trainSchedules.isEmpty {
                updateStatusBarWithTrain(popoverState.trainSchedules[0])
            } else if let errorMessage = popoverState.errorMessage {
                updateStatusBarWithError(errorMessage)
            }
        } else if !isActive && isMenuBarVisible {
            logInfo("Hiding train time display")
            isMenuBarVisible = false

            // Hide time text but keep the icon
            if let button = statusItem.button {
                button.attributedTitle = NSAttributedString(string: "")
            }
        }
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

        updateStatusIcon()

        if let button = statusItem.button {
            // Add action to show popover
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Check if the time text should be visible based on current time
        isMenuBarVisible = isCurrentTimeActive()

        // Always keep the status item visible (tram icon), just hide the time text if needed
        if !isMenuBarVisible {
            if let button = statusItem.button {
                button.attributedTitle = NSAttributedString(string: "")
            }
        }

        logInfo("Initial time text visibility: \(isMenuBarVisible ? "visible" : "hidden")")
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            if hasUpdateAvailable {
                // Create a composite image with a smaller tram and bell in upper left
                let tramImage = NSImage(
                    systemSymbolName: "tram.fill", accessibilityDescription: "Train")
                let bellImage = NSImage(
                    systemSymbolName: "bell.fill", accessibilityDescription: "Update")

                let size = NSSize(width: 18, height: 18)
                let compositeImage = NSImage(size: size)

                compositeImage.lockFocus()

                // Draw a smaller tram icon in the bottom-right area
                let tramSize: CGFloat = 14
                let tramRect = NSRect(
                    x: 5,
                    y: 0,
                    width: tramSize,
                    height: tramSize
                )
                tramImage?.draw(in: tramRect)

                // Draw bell in upper-left corner above the tram
                let bellSize: CGFloat = 8
                let bellRect = NSRect(
                    x: -1,
                    y: 10,
                    width: bellSize,
                    height: bellSize
                )

                bellImage?.draw(in: bellRect)

                compositeImage.unlockFocus()
                compositeImage.isTemplate = true

                button.image = compositeImage

            } else {
                let iconImage = NSImage(
                    systemSymbolName: "tram.fill", accessibilityDescription: "Train")
                iconImage?.isTemplate = true
                button.image = iconImage
            }
        }
    }

    @objc private func checkForUpdates() {
        // Only check for updates if the preference is enabled
        guard PreferencesManager.shared.preferences.checkForUpdates else {
            logInfo("Update checking is disabled in preferences")
            // Reset update status if checking is disabled
            if hasUpdateAvailable {
                hasUpdateAvailable = false
                updateStatusIcon()
            }
            return
        }

        logInfo("Checking for app updates...")
        networkManager.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let hasUpdate):
                    if hasUpdate != self.hasUpdateAvailable {
                        self.hasUpdateAvailable = hasUpdate
                        self.updateStatusIcon()

                        if hasUpdate {
                            logInfo("Update available - icon changed to exclamation mark")
                        } else {
                            logInfo("App is up to date - using normal train icon")
                        }
                    }
                case .failure(let error):
                    logWarning("Failed to check for updates: \(error.localizedDescription)")
                }
            }
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
            // Update station names in state before showing
            updateStationNames()

            // Set content size to ensure proper positioning (required for macOS 15+)
            if let hostingController = popover.contentViewController as? NSHostingController<TrainPopoverView> {
                popover.contentSize = hostingController.view.fittingSize
            }

            // For menu bar items, use .minY to position popover below the item
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    private func updateStationNames() {
        let preferences = PreferencesManager.shared.preferences
        let stations = Station.allStations

        // Find station names from the Station class based on preferences
        let fromStation = stations.first(where: { $0.id == preferences.fromStation })
        let toStation = stations.first(where: { $0.id == preferences.toStation })

        // Update state with station names
        popoverState.fromStationName = fromStation?.name ?? preferences.fromStation
        popoverState.toStationName = toStation?.name ?? preferences.toStation
    }

    @objc func showPreferences(_ sender: Any? = nil) {
        closePopover()
        showPreferencesPopover()
    }

    private func showPreferencesPopover() {
        if let button = statusItem.button {
            // Create the preferences view with callbacks for save/cancel
            let preferencesView = PreferencesView(
                onSave: { [weak self] in
                    self?.closePreferencesPopover()
                },
                onCancel: { [weak self] in
                    self?.closePreferencesPopover()
                }
            )

            // Set the view in the popover
            let hostingController = NSHostingController(rootView: preferencesView)
            preferencesPopover.contentViewController = hostingController

            // Set content size to ensure proper positioning (required for macOS 15+)
            preferencesPopover.contentSize = hostingController.view.fittingSize

            // Show the popover
            preferencesPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Start the event monitor if it's not already running
            preferencesEventMonitor?.start()
        }
    }

    private func closePreferencesPopover() {
        preferencesPopover.performClose(nil)
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

        // Reset display update timer to ensure consistent behavior with new preferences
        if let existingDisplayTimer = displayUpdateTimer {
            existingDisplayTimer.invalidate()
        }

        displayUpdateTimer = Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(updateDisplayWithoutFetching),
            userInfo: nil,
            repeats: true
        )

        // Check if menu bar should be visible with new preferences
        checkActiveHours()

        // Handle update checking preference changes
        configureUpdateCheckTimer()
    }

    private func configureUpdateCheckTimer() {
        let shouldCheckForUpdates = PreferencesManager.shared.preferences.checkForUpdates

        if shouldCheckForUpdates && updateCheckTimer == nil {
            // Enable update checking
            logInfo("Enabling update checking")
            checkForUpdates()
            updateCheckTimer = Timer.scheduledTimer(
                timeInterval: 24 * 60 * 60,  // 24 hours
                target: self,
                selector: #selector(checkForUpdates),
                userInfo: nil,
                repeats: true
            )
        } else if !shouldCheckForUpdates && updateCheckTimer != nil {
            // Disable update checking
            logInfo("Disabling update checking")
            updateCheckTimer?.invalidate()
            updateCheckTimer = nil

            // Reset icon to normal if update was available
            if hasUpdateAvailable {
                hasUpdateAvailable = false
                updateStatusIcon()
            }
        }
    }

    @objc private func fetchTrainSchedule(showLoading: Bool = true) {
        // Set the refresh state if we want to show loading
        if showLoading {
            popoverState.isRefreshing = true
            // SwiftUI automatically updates the view - no need to manually update content!
        }
        networkManager.fetchTrainSchedule { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                // Reset refresh state
                self.popoverState.isRefreshing = false

                switch result {
                case .success(let trainSchedules):
                    if !trainSchedules.isEmpty {
                        // Update state - SwiftUI will automatically update the view
                        self.popoverState.trainSchedules = trainSchedules
                        self.popoverState.errorMessage = nil
                        self.updateStatusBarWithTrain(trainSchedules[0])
                    } else {
                        self.popoverState.trainSchedules = []
                        self.popoverState.errorMessage = Constants.noTrainFoundMessage
                        self.updateStatusBarWithError(Constants.noTrainFoundMessage)
                    }
                case .failure(let error):
                    self.popoverState.trainSchedules = []
                    self.popoverState.errorMessage = error.localizedDescription
                    self.updateStatusBarWithError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func manualRefresh() {
        logInfo("Refresh request by user")

        // Set refresh state immediately to update the UI
        popoverState.isRefreshing = true
        // SwiftUI automatically updates the view - no need to manually update content!

        // small delay allows the animation to be visible to the user
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchTrainSchedule(showLoading: false)
        }
    }

    @objc private func updateDisplayWithoutFetching() {
        // Don't do anything if we have no train schedules or if we're outside active hours
        guard !popoverState.trainSchedules.isEmpty && isMenuBarVisible else {
            return
        }

        // Find all trains that haven't departed yet, considering walk time
        let now = Date()
        let walkTimeDurationSec = TimeInterval(
            PreferencesManager.shared.preferences.walkTimeDurationMin * 60)

        let upcomingTrains = popoverState.trainSchedules.filter {
            let timeUntilDeparture = $0.departureTime.timeIntervalSince(now)

            if PreferencesManager.shared.preferences.walkTimeDurationMin > 0 {
                return timeUntilDeparture > walkTimeDurationSec
            } else {
                return timeUntilDeparture > -60  // Allow trains departing within the last minute
            }
        }

        // Update the train schedules array to only include upcoming trains
        if upcomingTrains.count < popoverState.trainSchedules.count && !upcomingTrains.isEmpty {
            logInfo("Updating display without fetching new data")
            popoverState.trainSchedules = upcomingTrains
        }

        if let nextTrain = upcomingTrains.first {
            // Update the menu bar with the next upcoming train
            updateStatusBarWithTrain(nextTrain)
            // SwiftUI automatically updates the popover view - no manual update needed!

            NotificationCenter.default.post(name: .trainDisplayUpdate, object: nil)

        } else if upcomingTrains.isEmpty && !popoverState.trainSchedules.isEmpty {
            // All trains have departed, show no trains message
            logInfo("Updating display without fetching new data")
            popoverState.trainSchedules = []
            popoverState.errorMessage = Constants.noTrainFoundMessage
            updateStatusBarWithError(Constants.noTrainFoundMessage)
            // SwiftUI automatically updates the popover view - no manual update needed!
        }
    }

    private func updateStatusBarWithTrain(_ train: TrainSchedule) {
        if let button = statusItem.button {
            // Only show train time if within active schedule
            if !isMenuBarVisible {
                button.attributedTitle = NSAttributedString(string: "")
                return
            }

            let departureTimeString = DateFormatters.timeFormatter.string(from: train.departureTime)
            let preferences = PreferencesManager.shared.preferences

            let directionArrow = preferences.isDirectionReversed ? "⤌" : "⤍"
            let displayString = "\(departureTimeString) \(directionArrow)"

            // Use a monospaced font to ensure consistent width
            let font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize, weight: .regular)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]

            button.attributedTitle = NSAttributedString(
                string: displayString,
                attributes: attributes
            )

            setStationDirectionsTooltip(for: button)
        }
    }

    private func updateStatusBarWithError(_ message: String) {
        if let button = statusItem.button {
            // Only show error text if within active schedule
            if !isMenuBarVisible {
                button.attributedTitle = NSAttributedString(string: "")
                return
            }

            let menubarText =
                message == Constants.noTrainFoundMessage
                ? Constants.menuBarNoResultsText : Constants.menuBarErrorText
            let textColor =
                message == Constants.noTrainFoundMessage ? NSColor.labelColor : NSColor.systemRed

            // Use the same monospaced font for consistency
            let font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize, weight: .regular)

            button.attributedTitle = NSAttributedString(
                string: menubarText,
                attributes: [
                    NSAttributedString.Key.foregroundColor: textColor,
                    NSAttributedString.Key.font: font,
                ]
            )

            setStationDirectionsTooltip(for: button)
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

        // Determine which stations to use based on the direction flag
        let fromStationId =
            preferences.isDirectionReversed ? preferences.toStation : preferences.fromStation
        let toStationId =
            preferences.isDirectionReversed ? preferences.fromStation : preferences.toStation

        let officialSiteUrl = URL(
            string: "https://www.rail.co.il/?" + "page=routePlanSearchResults"
                + "&fromStation=\(fromStationId)" + "&toStation=\(toStationId)"
                + "&date=\(currentDateStr)" + "&hours=\(hours)" + "&minutes=\(minutes)"
                + "&scheduleType=1"
        )

        if let url = officialSiteUrl {
            NSWorkspace.shared.open(url)
        }
    }

    func windowWillClose(_ notification: Notification) {
        // If our preferences window is closing, clear the reference
        if let closingWindow = notification.object as? NSWindow,
            closingWindow === preferencesWindow
        {
            // Ensure the window is completely released
            preferencesWindow = nil
        }

        // If our about window is closing, clear the reference
        if let closingWindow = notification.object as? NSWindow,
            closingWindow === aboutWindow
        {
            // Ensure the window is completely released
            aboutWindow = nil
        }
    }

    private func reverseTrainDirection() {
        let preferences = PreferencesManager.shared.preferences

        logInfo("Toggling train direction")

        PreferencesManager.shared.savePreferences(
            fromStation: preferences.fromStation,
            toStation: preferences.toStation,
            upcomingItemsCount: preferences.upcomingItemsCount,
            launchAtLogin: preferences.launchAtLogin,
            checkForUpdates: preferences.checkForUpdates,
            refreshInterval: preferences.refreshInterval,
            activeDays: preferences.activeDays,
            activeStartHour: preferences.activeStartHour,
            activeEndHour: preferences.activeEndHour,
            walkTimeDurationMin: preferences.walkTimeDurationMin,
            maxTrainChanges: preferences.maxTrainChanges,
            isDirectionReversed: !preferences.isDirectionReversed
        )

        // Trigger a refresh to update the train schedule
        NotificationCenter.default.post(name: .reloadPreferencesChanged, object: nil)
    }

    private func isCurrentTimeActive() -> Bool {
        let preferences = PreferencesManager.shared.preferences
        let calendar = Calendar.current
        let now = Date()

        // Check if today is an active day
        let weekday = calendar.component(.weekday, from: now)  // 1 = Sunday, 2 = Monday, etc.
        let dayIndex = weekday - 1  // Convert to 0-based index (0 = Sunday)

        // Check if the current day is marked as active
        guard preferences.activeDays.count > dayIndex && preferences.activeDays[dayIndex] else {
            return false
        }

        // Check if the current hour is within the active hours
        let hour = calendar.component(.hour, from: now)
        let isInActiveHours =
            hour >= preferences.activeStartHour && hour <= preferences.activeEndHour

        return isInActiveHours
    }

    private func selectFavoriteRoute(_ routeId: String) {
        logInfo("Selecting favorite route with ID: \(routeId)")

        // Apply the favorite route - this changes the current stations
        if PreferencesManager.shared.applyFavoriteRoute(id: routeId) {
            // Update the station names in the popover state immediately
            updateStationNames()

            // Trigger a refresh to show trains for the selected route
            NotificationCenter.default.post(name: .reloadPreferencesChanged, object: nil)
            // SwiftUI automatically updates the popover view - no manual update needed!
        }
    }

    private func setStationDirectionsTooltip(for button: NSStatusBarButton) {
        let preferences = PreferencesManager.shared.preferences
        let stations = Station.allStations
        let fromStation =
            stations.first(where: { $0.id == preferences.fromStation })?.name
            ?? preferences.fromStation
        let toStation =
            stations.first(where: { $0.id == preferences.toStation })?.name ?? preferences.toStation
        let directionArrow = preferences.isDirectionReversed ? "←" : "→"
        let updatePrefix = hasUpdateAvailable ? "(Update avail.) " : ""
        let directionText = "\(updatePrefix) \(fromStation) \(directionArrow) \(toStation)"
        button.toolTip = directionText
    }

    func getAppVersion() -> String {
        return Constants.appVersion
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
