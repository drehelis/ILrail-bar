import SwiftUI
import ServiceManagement

struct SearchableStationPicker: View {
    let label: String
    let stations: [Station]
    @Binding var selectedStationId: String
    @State private var isExpanded: Bool = false
    @State private var searchText: String = ""
    
    var filteredStations: [Station] {
        if searchText.isEmpty {
            return stations
        } else {
            return stations.filter { station in
                station.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var selectedStationName: String {
        stations.first(where: { $0.id == selectedStationId })?.name ?? "Select station"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(label)
                    .frame(width: 150, alignment: .leading)
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    HStack {
                        Text(selectedStationName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(isExpanded ? .degrees(180) : .degrees(0))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 6)
    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredStations) { station in
                                Button(action: {
                                    selectedStationId = station.id
                                    isExpanded = false
                                    searchText = ""
                                }) {
                                    Text(station.name)
                                        .foregroundColor(selectedStationId == station.id ? .accentColor : Color.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if station.id != filteredStations.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(height: min(300, CGFloat(filteredStations.count * 30)))
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                // Reset search when closing dropdown
                searchText = ""
            }
        }
    }
}

struct PreferencesView: View {
    @State private var selectedFromStation: String
    @State private var selectedToStation: String
    @State private var upcomingItemsCount: Int
    @State private var launchAtLogin: Bool
    @State private var refreshInterval: Int
    @State private var activeDays: [Bool]
    @State private var activeStartHour: Int
    @State private var activeEndHour: Int
    @State private var walkTimeDurationMin: Int
    @State private var maxTrainChanges: Int
    @State private var isDirectionReversed: Bool
    @State private var stations: [Station] = Station.allStations
    @State private var isLoading: Bool = false
    @State private var showAdditionalFilters: Bool = false
    @State private var showSaveRouteDialog: Bool = false
    @State private var showManageRoutesDialog: Bool = false
    @State private var favoriteRoutes: [FavoriteRoute] = []
    @State private var selectedFavoriteRouteName: String = ""
    
    // Callback functions for popover actions
    let onSave: () -> Void
    let onCancel: () -> Void
    
    init(onSave: @escaping () -> Void = {}, onCancel: @escaping () -> Void = {}) {
        let preferences = PreferencesManager.shared.preferences
        
        // If direction is reversed, we swap from/to stations in the UI
        if preferences.isDirectionReversed {
            _selectedFromStation = State(initialValue: preferences.toStation)
            _selectedToStation = State(initialValue: preferences.fromStation)
        } else {
            _selectedFromStation = State(initialValue: preferences.fromStation)
            _selectedToStation = State(initialValue: preferences.toStation)
        }
        
        _upcomingItemsCount = State(initialValue: preferences.upcomingItemsCount)
        _launchAtLogin = State(initialValue: preferences.launchAtLogin)
        _refreshInterval = State(initialValue: preferences.refreshInterval)
        _activeDays = State(initialValue: preferences.activeDays)
        _activeStartHour = State(initialValue: preferences.activeStartHour)
        _activeEndHour = State(initialValue: preferences.activeEndHour)
        _walkTimeDurationMin = State(initialValue: preferences.walkTimeDurationMin)
        _maxTrainChanges = State(initialValue: preferences.maxTrainChanges)
        _isDirectionReversed = State(initialValue: preferences.isDirectionReversed)
        _favoriteRoutes = State(initialValue: preferences.favoriteRoutes)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            
            if isLoading {
                ProgressView("Loading stations...")
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 20) {
                    HStack(alignment: .center) {
                        Text("Launch at Login")
                            .frame(width: 150, alignment: .leading)
                        
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    SearchableStationPicker(
                        label: "Departure Station",
                        stations: stations,
                        selectedStationId: $selectedFromStation
                    )
                    
                    SearchableStationPicker(
                        label: "Arrival Station",
                        stations: stations,
                        selectedStationId: $selectedToStation
                    )
                    
                    HStack {                        
                        Button(action: {
                            showSaveRouteDialog = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption)
                                Text("Add Route to Favorites")
                                    .font(.callout)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer().frame(width: 10)

                        Button(action: {
                            showManageRoutesDialog = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                    .font(.caption)
                                Text("Manage")
                                    .font(.callout)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                    }
                    .padding(.vertical, 4)

                    Divider()

                    HStack(alignment: .center) {

                        Text("Walking time duration")
                            .frame(width: 150, alignment: .leading)
                            .help("The time it takes to walk from your location to the station. Adjusts schedule accordingly.")
                        
                        HStack(spacing: 5) {
                            Text("\(walkTimeDurationMin)")
                                .frame(minWidth: 20, alignment: .trailing)
                            Stepper("", value: $walkTimeDurationMin, in: 0...60)
                                .labelsHidden()
                            Text("minutes")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(alignment: .center) {
                        Text("Schedule fetch interval")
                            .frame(width: 150, alignment: .leading)
                        
                        Picker("", selection: $refreshInterval) {
                            Text("10 seconds").tag(10)
                            Text("30 seconds").tag(30)
                            Text("1 minute").tag(60)
                            Text("2 minutes").tag(120)
                            Text("5 minutes").tag(300)
                            Text("10 minutes").tag(600)
                            Text("15 minutes").tag(900)
                            Text("30 minutes").tag(1800)
                            Text("1 hour").tag(3600)
                        }
                        .pickerStyle(PopUpButtonPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                                                            
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Active on days:")
                            .frame(width: 150, alignment: .leading)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<7) { index in
                                let day = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][index]
                                Button(action: {
                                    activeDays[index].toggle()
                                }) {
                                    Text(day)
                                        .frame(width: 40, height: 24)
                                        .background(activeDays[index] ? Color.blue : Color(NSColor.controlBackgroundColor))
                                        .foregroundColor(activeDays[index] ? .white : .primary)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack(alignment: .center) {
                        Text("Active hours:")
                            .frame(width: 150, alignment: .leading)
                        
                        HStack(spacing: 5) {
                            Picker("", selection: $activeStartHour) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .frame(width: 100)
                            .pickerStyle(PopUpButtonPickerStyle())
                            
                            Picker("", selection: $activeEndHour) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .frame(width: 100)
                            .pickerStyle(PopUpButtonPickerStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showAdditionalFilters.toggle()
                    }) {
                        HStack {
                            Text("Additional Filters")
                            Spacer()
                            Image(systemName: showAdditionalFilters ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    if showAdditionalFilters {
                        VStack(spacing: 20) {
                            HStack(alignment: .center) {
                                Text("Upcoming list items")
                                    .frame(width: 150, alignment: .leading)
                                
                                HStack(spacing: 5) {
                                    Text("\(upcomingItemsCount)")
                                        .frame(minWidth: 20, alignment: .trailing)
                                    Stepper("", value: $upcomingItemsCount, in: 1...10)
                                        .labelsHidden()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            HStack(alignment: .center) {
                                Text("Limit train change to")
                                    .frame(width: 150, alignment: .leading)

                                Picker("", selection: $maxTrainChanges) {
                                    Text("No limit").tag(-1)
                                    Text("Direct only").tag(0)
                                    Text("1 change").tag(1)
                                    Text("2 changes").tag(2)
                                    Text("3 changes").tag(3)
                                }
                                .pickerStyle(PopUpButtonPickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(width: 100)
                
                Button("Save") {
                    PreferencesManager.shared.savePreferences(
                        fromStation: isDirectionReversed ? selectedToStation : selectedFromStation,
                        toStation: isDirectionReversed ? selectedFromStation : selectedToStation,
                        upcomingItemsCount: upcomingItemsCount,
                        launchAtLogin: launchAtLogin,
                        refreshInterval: refreshInterval,
                        activeDays: activeDays,
                        activeStartHour: activeStartHour,
                        activeEndHour: activeEndHour,
                        walkTimeDurationMin: walkTimeDurationMin,
                        maxTrainChanges: maxTrainChanges,
                        isDirectionReversed: isDirectionReversed
                    )
                    
                    // Configure launch at login
                    updateLaunchAtLogin(launchAtLogin)
                    
                    // Notify the app to refresh train schedules with new preferences
                    NotificationCenter.default.post(name: .reloadPreferencesChanged, object: nil)
                    
                    onSave()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 100)
                .disabled(isLoading)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .animation(.easeInOut, value: isLoading)
        .frame(width: 400, height: isLoading ? 200 : nil)
        .fixedSize(horizontal: true, vertical: true)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadStations()
        }
        .sheet(isPresented: $showSaveRouteDialog) {
            SaveRouteView(
                isPresented: $showSaveRouteDialog,
                stations: stations,
                onSave: { routeName in
                    // Save current selections as favorite route exactly as shown in the UI
                    // Always use the stations as they appear in the UI fields, regardless of direction flag
                    
                    // Create a new favorite route with the current station selections
                    let newRoute = FavoriteRoute(
                        name: routeName,
                        fromStation: selectedFromStation,
                        toStation: selectedToStation,
                        isDirectionReversed: isDirectionReversed
                    )
                    
                    var updatedRoutes = PreferencesManager.shared.preferences.favoriteRoutes
                    
                    // Replace if a route with the same name exists, otherwise add
                    if let index = updatedRoutes.firstIndex(where: { $0.name == routeName }) {
                        updatedRoutes[index] = newRoute
                    } else {
                        updatedRoutes.append(newRoute)
                    }
                    
                    updatedRoutes.sort { $0.name < $1.name }
                    
                    PreferencesManager.shared.savePreferences(
                        fromStation: PreferencesManager.shared.preferences.fromStation,
                        toStation: PreferencesManager.shared.preferences.toStation,
                        favoriteRoutes: updatedRoutes
                    )
                    
                    favoriteRoutes = updatedRoutes
                }
            )
        }
        .sheet(isPresented: $showManageRoutesDialog) {
            ManageFavoritesView(
                isPresented: $showManageRoutesDialog,
                stations: stations,
                onRoutesChanged: {
                    // Refresh favorite routes list when routes are edited or deleted
                    favoriteRoutes = PreferencesManager.shared.preferences.favoriteRoutes
                }
            )
        }
    }
    
    private func loadStations() {
        // Only show loading if we have default stations
        if stations.count <= 5 {
            isLoading = true
        }
        
        // Update stations when view appears
        stations = Station.allStations
        
        // Setup notification observer for stations loaded
        NotificationCenter.default.addObserver(
            forName: .stationsLoaded,
            object: nil,
            queue: .main
        ) { _ in
            // Update stations when loaded from remote
            self.stations = Station.allStations
            self.isLoading = false
            
            // Check if currently selected stations still exist in the new data
            if !self.stations.contains(where: { $0.id == self.selectedFromStation }) {
                self.selectedFromStation = Station.defaultStations.first?.id ?? ""
            }
            if !self.stations.contains(where: { $0.id == self.selectedToStation }) {
                self.selectedToStation = Station.defaultStations.last?.id ?? ""
            }
        }
        
        // Actively fetch stations if needed
        if stations.count <= 5 {
            Station.fetchStations { fetchedStations in
                DispatchQueue.main.async {
                    if let fetchedStations = fetchedStations, !fetchedStations.isEmpty {
                        Station.setStations(fetchedStations)
                        self.stations = fetchedStations
                        self.isLoading = false
                        
                        // Notify that stations have been loaded
                        NotificationCenter.default.post(name: .stationsLoaded, object: nil)
                    } else {
                        // If fetch failed, use default stations and hide loading
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logInfo("Launch at login enabled")

            } else {
                try SMAppService.mainApp.unregister()
                logInfo("Launch at login disabled")
            }
        } catch {
            logError("Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
    
    private func applyFavoriteRoute(_ routeId: String) {
        guard let route = PreferencesManager.shared.preferences.favoriteRoutes.first(where: { $0.id == routeId }) else {
            return
        }
        
        selectedFromStation = route.fromStation
        selectedToStation = route.toStation
        isDirectionReversed = route.isDirectionReversed
        selectedFavoriteRouteName = route.name
    }
}

// Custom button style that works on older macOS versions
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}