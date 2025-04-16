import SwiftUI
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var trainScheduleTimer: Timer?
    private let networkManager = NetworkManager()
    private var preferencesWindow: NSWindow?
    private var aboutWindow: NSWindow?
    
    // Constants
    private let noTrainFoundMessage = "No trains found for route" 
    private let aboutAppVersion = "ILrail-bar" 

        
    @objc func copyTrainInfoToClipboard(_ sender: NSMenuItem) {
        var textToCopy = ""
        
        if let attributedTitle = sender.attributedTitle {
            textToCopy = attributedTitle.string
        } else if !sender.title.isEmpty {
            textToCopy = sender.title
        }
        
        // Copy to clipboard if text is not empty
        if !textToCopy.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToCopy, forType: .string)
        }
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
    
    private func rebuildMenu(withTrainsOrError: Bool, errorItems: [NSMenuItem]? = nil, trainItems: [NSMenuItem]? = nil) {
        // Keep track of important menu items
        let importantItems = menu.items.filter { item in
            return item.title == "Preferences..." || 
                   item.title == "Refresh" || 
                   item.title == "About" ||
                   item.title == "Quit" ||
                   item.isSeparatorItem
        }
        
        // Clear all items
        menu.removeAllItems()
        
        // Add separator at the top
        menu.addItem(NSMenuItem.separator())
        
        // Add train information or error items
        if withTrainsOrError {
            if let trainItems = trainItems {
                trainItems.forEach { menu.addItem($0) }
            } else if let errorItems = errorItems {
                errorItems.forEach { menu.addItem($0) }
            }
        }
        
        // Add a separator before the control items
        menu.addItem(NSMenuItem.separator())
        
        // Restore important menu items
        for item in importantItems {
            if item.title == "Preferences..." || item.title == "Refresh" || item.title == "About" || item.title == "Quit" {
                // Make sure our About menu item always has its action and target set
                if item.title == "About" {
                    item.action = #selector(showAbout(_:))
                    item.target = self
                }
                menu.addItem(item)
            } else if item.isSeparatorItem && menu.items.last?.title != nil {
                // Add separators only between items, not after another separator
                menu.addItem(NSMenuItem.separator())
            }
        }
    }
    
    // This method is called before applicationDidFinishLaunching
    func applicationWillFinishLaunching(_ notification: Notification) {
        // LSUIElement is properly set in Info.plist, no need to explicitly set activation policy
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Fetch station data as soon as the app starts
        fetchStationData()
        
        setupMenuBar()
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
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use a train icon with better styling
            let tramImage = NSImage(systemSymbolName: "tram.fill", accessibilityDescription: "Train")
            tramImage?.isTemplate = true  // Ensures proper appearance in dark/light modes
            button.image = tramImage
            
            // Add loading message with a styled appearance
            button.attributedTitle = NSAttributedString(
                string: " Loading...",
                attributes: [
                    NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor,
                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                ]
            )
        }
        
        // Create menu with better visual organization
        menu = NSMenu()
        
        // Add a separator at the top of the menu
        menu.addItem(NSMenuItem.separator())
        
        // Add preferences menu item with direct action block instead of selector
        let prefsItem = NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ",")
        prefsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Preferences")
        prefsItem.target = self
        // Set action separately after configuration
        prefsItem.action = #selector(showPreferences(_:))
        menu.addItem(prefsItem)
        
        // Add refresh item with icon
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add about item with icon
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Add a separator before the quit item
        menu.addItem(NSMenuItem.separator())
        
        // Add quit item with icon
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func showPreferences(_ sender: Any?) {
        // Create a new hosting view with an instance of PreferencesView
        // Pass nil for the window as we'll set it properly after creating it
        let preferencesView = PreferencesView()
        let hostingView = NSHostingView(rootView: preferencesView)
        
        createAndShowWindow(
            size: NSSize(width: 400, height: 250),
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
        if showLoading, let button = statusItem.button {
            button.attributedTitle = NSAttributedString(
                string: " Loading...",
                attributes: [
                    NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor,
                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                ]
            )
        }
        
        networkManager.fetchTrainSchedule { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let trainSchedules):
                    if !trainSchedules.isEmpty {
                        // Pass all train schedules to the update method
                        self.updateMenuBarWithTrains(trainSchedules)
                    } else {
                        self.updateMenuBarWithError(self.noTrainFoundMessage)
                    }
                case .failure(let error):
                    self.updateMenuBarWithError(error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func manualRefresh() {
        logInfo("Refresh request by user")
        fetchTrainSchedule(showLoading: true)
    }
    
    // Helper functions to create small-sized attributed text and append it
    private func createSmallText(_ text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        ])
    }

    private func appendSmallText(_ smallText: String, to attributedString: NSMutableAttributedString) {
        attributedString.append(createSmallText(smallText))
    }

    private func setupCommonMenuItems() -> (stationItem: NSMenuItem, items: [NSMenuItem]) {
        // Get the current route information from preferences
        let preferences = PreferencesManager.shared.preferences
        let stations = Station.allStations
        
        // Find station names from the Station class based on preferences
        let fromStation = stations.first(where: { $0.id == preferences.fromStation })
        let toStation = stations.first(where: { $0.id == preferences.toStation })
        
        // Use the found station names, or fall back to the IDs if not found
        let fromStationName = fromStation?.name ?? preferences.fromStation
        let toStationName = toStation?.name ?? preferences.toStation
        
        // Add station names at the top
        let stationsItem = NSMenuItem(title: "\(fromStationName)\t→\t\(toStationName)", action: nil, keyEquivalent: "")
        
        // Create common items array with the separator and website link
        var commonItems: [NSMenuItem] = []
        commonItems.append(NSMenuItem.separator())
        commonItems.append(createWebsiteMenuItem())
        
        return (stationsItem, commonItems)
    }
    
    private func updateMenuBarWithTrains(_ trainSchedules: [TrainSchedule]) {
        // Create train menu items
        var trainItems: [NSMenuItem] = []
        
        // Get common menu items
        let commonMenuSetup = setupCommonMenuItems()
        trainItems.append(commonMenuSetup.stationItem)
        trainItems.append(NSMenuItem.separator())
        
        // Get the first train for the status bar display
        let firstTrain = trainSchedules[0]
        let timeUntilDepartureSeconds = firstTrain.departureTime.timeIntervalSinceNow // in seconds
        let timeUntilDepartureMinutes = timeUntilDepartureSeconds / 60 // convert to minutes        
        logDebug("Time until departure: \(timeUntilDepartureMinutes) minutes")
        
        // Display the next train
        let _travelTime = DateFormatters.formatTravelTime(from: firstTrain.departureTime, to: firstTrain.arrivalTime)
        let _departureTime = DateFormatters.timeFormatter.string(from: firstTrain.departureTime)
        let _arrivalTime = DateFormatters.timeFormatter.string(from: firstTrain.arrivalTime)

        let firstTrainTitle = "\(_departureTime)\t→\t\(_arrivalTime) (\(firstTrain.trainChanges))"
        
        // Create an attributed string for the first train info
        let firstTrainAttrString = NSMutableAttributedString(string: firstTrainTitle)
        
        appendSmallText(" [\(_travelTime)]", to: firstTrainAttrString)
        
        if firstTrain.trainChanges > 0 && !firstTrain.allTrainNumbers.isEmpty {
            let trainNumbersString = firstTrain.allTrainNumbers.map { "#\($0)" }.joined(separator: ", ")
            appendSmallText(" (\(trainNumbersString))", to: firstTrainAttrString)
        } else if !firstTrain.trainNumber.isEmpty {
            appendSmallText(" (#\(firstTrain.trainNumber))", to: firstTrainAttrString)
        }
        
        let firstTrainInfoItem = NSMenuItem(
            title: "",
            action: #selector(copyTrainInfoToClipboard(_:)), 
            keyEquivalent: ""
        )
        firstTrainInfoItem.attributedTitle = firstTrainAttrString
        firstTrainInfoItem.target = self
        trainItems.append(NSMenuItem(title: "Next:", action: nil, keyEquivalent: ""))
        trainItems.append(firstTrainInfoItem)
        
        // Add up to the configured number of additional trains
        let preferences = PreferencesManager.shared.preferences
        let totalTrainsToShow = preferences.upcomingItemsCount + 1 // First train + additional trains
        let maxTrainsToShow = min(totalTrainsToShow, trainSchedules.count)
        
        if trainSchedules.count > 1 {
            trainItems.append(NSMenuItem.separator())
            trainItems.append(NSMenuItem(title: "Upcoming:", action: nil, keyEquivalent: ""))
            
            for i in 1..<maxTrainsToShow {
                let train = trainSchedules[i]
                
                // Create the basic train info title
                let _travelTime = DateFormatters.formatTravelTime(from: train.departureTime, to: train.arrivalTime)
                let _departureTime = DateFormatters.timeFormatter.string(from: train.departureTime)
                let _arrivalTime = DateFormatters.timeFormatter.string(from: train.arrivalTime)

                let trainBaseTitle = "\(_departureTime)\t→\t\(_arrivalTime) (\(train.trainChanges))"
                let trainAttrString = NSMutableAttributedString(string: trainBaseTitle)
                
                appendSmallText(" [\(_travelTime)]", to: trainAttrString)
                
                if train.trainChanges > 0 && !train.allTrainNumbers.isEmpty {
                    let trainNumbersString = train.allTrainNumbers.map { "#\($0)" }.joined(separator: ", ")
                    appendSmallText(" (\(trainNumbersString))", to: trainAttrString)
                } else if !train.trainNumber.isEmpty {
                    appendSmallText(" (#\(train.trainNumber))", to: trainAttrString)
                }
                
                let trainInfoItem = NSMenuItem(
                    title: "",
                    action: #selector(copyTrainInfoToClipboard(_:)), 
                    keyEquivalent: ""
                )
                trainInfoItem.attributedTitle = trainAttrString
                trainInfoItem.target = self
                trainItems.append(trainInfoItem)
            }
        }
        
        trainItems.append(contentsOf: commonMenuSetup.items)
        
        // Use the helper method to rebuild the menu
        rebuildMenu(withTrainsOrError: true, trainItems: trainItems)
        
        if let button = statusItem.button {
            let departureTimeString = DateFormatters.timeFormatter.string(from: firstTrain.departureTime)
            
            let preferences = PreferencesManager.shared.preferences
            let redTimeUntilDeparture = TimeInterval(preferences.redAlertMinutes * 60) // Convert minutes to seconds
            let blueTimeUntilDeparture = TimeInterval(preferences.blueAlertMinutes * 60) // Convert minutes to seconds
            
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
    
    private func updateMenuBarWithError(_ message: String) {
        // Create error menu items
        var errorItems: [NSMenuItem] = []
        
        // Get common menu items
        let commonMenuSetup = setupCommonMenuItems()
        errorItems.append(commonMenuSetup.stationItem)
        errorItems.append(NSMenuItem.separator())
        
        // Add error information
        let errorItem = NSMenuItem(title: message, action: nil, keyEquivalent: "")
        errorItems.append(errorItem)
        
        errorItems.append(contentsOf: commonMenuSetup.items)
        
        // Use the helper method to rebuild the menu
        rebuildMenu(withTrainsOrError: true, errorItems: errorItems)
        
        // Update status bar with error indicator
        if let button = statusItem.button {
            let menubarText = message == noTrainFoundMessage ? " No results" : " Error"            
            let textColor = message == noTrainFoundMessage ? NSColor.labelColor : NSColor.systemRed
            
            button.attributedTitle = NSAttributedString(
                string: menubarText,
                attributes: [NSAttributedString.Key.foregroundColor: textColor]
            )
        }
    }
        
    @objc func showAbout(_ sender: Any?) {      
        let aboutView = AboutView(window: aboutWindow ?? NSWindow())
        let hostingView = NSHostingView(rootView: aboutView)
        createAndShowWindow(
            size: NSSize(width: 350, height: 350),
            title: aboutAppVersion,
            styleMask: [.titled, .closable],
            center: true,
            view: hostingView,
            storeIn: &aboutWindow
        )
    }
    
    @objc private func openRailWebsite(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Helper method to create the "View on Official website" menu item
    private func createWebsiteMenuItem() -> NSMenuItem {
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
        
        let websiteItem = NSMenuItem(title: "View on Official website", action: #selector(openRailWebsite(_:)), keyEquivalent: "")
        websiteItem.representedObject = officialSiteUrl
        websiteItem.target = self
        websiteItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: "Web browser")
        return websiteItem
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
        
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showPreferences(_:)) || 
           menuItem.action == #selector(showAbout(_:)) {
            return true
        }
        return true
    }
}
