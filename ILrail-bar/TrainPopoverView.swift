import SwiftUI
import UserNotifications

struct TrainPopoverView: View {
    @ObservedObject var state: PopoverState

    @State private var showSaveRouteDialog: Bool = false
    @State private var showManageRoutesDialog: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with station names and reverse button
            HeaderView(
                fromStationName: state.fromStationName,
                toStationName: state.toStationName,
                isDirectionReversed: PreferencesManager.shared.preferences.isDirectionReversed,
                favoriteRoutes: PreferencesManager.shared.preferences.favoriteRoutes,
                stations: Station.allStations,
                onReverseDirection: state.reverseDirection,
                onSelectFavoriteRoute: state.selectFavoriteRoute
            )

            Divider()

            // Content - trains or error
            if !state.trainSchedules.isEmpty {
                // Next train section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Next\(DateFormatters.formatDateLabel(for: state.trainSchedules[0].departureTime))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)

                    TrainInfoRow(
                        train: state.trainSchedules[0]
                    )
                    .id("\(state.trainSchedules[0].trainNumber)-\(state.trainSchedules[0].departureTime.timeIntervalSince1970)")

                    // Upcoming trains
                    if state.trainSchedules.count > 1 {
                        Divider()
                            .padding(.vertical, 5)

                        // Get the date for the second train (first upcoming train)
                        let upcomingDateLabel = DateFormatters.formatDateLabel(for: state.trainSchedules[1].departureTime)

                        Text("Upcoming\(upcomingDateLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 5)

                        // Only show configured number of trains
                        let maxItems = min(state.trainSchedules.count, PreferencesManager.shared.preferences.upcomingItemsCount + 1)
                        ForEach(1..<maxItems, id: \.self) { index in
                            TrainInfoRow(
                                train: state.trainSchedules[index]
                            )
                            .id("\(state.trainSchedules[index].trainNumber)-\(state.trainSchedules[index].departureTime.timeIntervalSince1970)")

                            if index < maxItems - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                        let preferences = PreferencesManager.shared.preferences
                        if preferences.maxTrainChanges != -1 {
                            HStack {
                                Text("Some routes are filtered out")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 3)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 5)

                Divider()
            } else if let errorMessage = state.errorMessage {
                // Error view
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        if errorMessage == "No trains found for route" {
                            VStack(spacing: 10) {
                                Image(systemName: "train.side.rear.car")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                                Text(errorMessage)
                                    .foregroundColor(.secondary)

                                let preferences = PreferencesManager.shared.preferences
                                if preferences.walkTimeDurationMin > 0 || preferences.maxTrainChanges != -1 {
                                    VStack(spacing: 5) {
                                        Text("This may be due to active filters")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()
                    }

                    Spacer()
                }
                .frame(height: 180)

                Divider()
            }
            
            HStack(spacing: 15) {
                LinkButton(icon: "safari", text: "Website", action: state.openWebsite)

                LinkButton(
                    icon: "arrow.clockwise",
                    text: state.isRefreshing ? "Loading" : "Refresh ",
                    action: state.refresh,
                    isRefreshing: state.isRefreshing
                )

                LinkButton(icon: "gear", text: "Prefs.", action: state.showPreferences)

                MoreMenuButton(onAbout: state.showAbout, onQuit: state.quit)
            }
            .padding()
        }
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showSaveRouteDialog) {
            SaveRouteView(
                isPresented: $showSaveRouteDialog,
                stations: Station.allStations,
                onSave: { routeName in
                    PreferencesManager.shared.saveCurrentRouteAsFavorite(name: routeName)
                }
            )
        }
        .sheet(isPresented: $showManageRoutesDialog) {
            ManageFavoritesView(
                isPresented: $showManageRoutesDialog,
                stations: Station.allStations
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveCurrentRoute)) { _ in
            showSaveRouteDialog = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .manageRoutes)) { _ in
            showManageRoutesDialog = true
        }
    }
}

struct TrainInfoRow: View {
    let train: TrainSchedule

    @State private var isCopied: Bool = false
    @State private var hasNotification: Bool = false
    @State private var refreshID: UUID = UUID()
    
    var body: some View {
        Button(action: {
            copyTrainInfoToClipboard()
            withAnimation { isCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { isCopied = false }
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(timeString(for: train.departureTime))
                            .font(.system(.body, design: .default).monospacedDigit())
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .id("departure-\(refreshID)")
                        
                        Text("→")
                            .foregroundStyle(.secondary)
                        
                        Text(timeString(for: train.arrivalTime))
                            .font(.system(.body, design: .default).monospacedDigit())
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .id("arrival-\(refreshID)")
                        
                        Spacer(minLength: 4)
                        
                        Group {
                            Text("[\(travelTimeString())]")
                                .font(.system(.caption, design: .default).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .id("travel-\(refreshID)")
                            
                            if train.trainChanges > 0 && !train.platform.isEmpty && train.allPlatforms.count > 1 {
                                Text("(Plat. #\(train.allPlatforms.joined(separator: ", ")))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if !train.platform.isEmpty {
                                Text("(Plat. #\(train.platform))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("(\(train.trainChanges))")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()

                HStack(spacing: 4) {
                    if hasNotification {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }

                    if isCopied {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal)
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if hasNotification {
                Button(action: {
                    removeNotification()
                }) {
                    Label("Remove Notification", systemImage: "clock.badge.xmark")
                }
            } else {
                Button(action: {
                    scheduleNotification()
                }) {
                    Label("Set Notification", systemImage: "clock")
                }
            }

            Button(action: {
                copyTrainInfoToClipboard()
                withAnimation { isCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { isCopied = false }
                }
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trainDisplayUpdate)) { _ in
            refreshID = UUID()
        }
        .onAppear {
            checkForExistingNotification()
        }
    }

    private func timeString(for date: Date) -> String {
        return DateFormatters.timeFormatter.string(from: date)
    }

    private func travelTimeString() -> String {
        return DateFormatters.formatTravelTime(from: train.departureTime, to: train.arrivalTime)
    }

    private func copyTrainInfoToClipboard() {
        let departureTime = DateFormatters.timeFormatter.string(from: train.departureTime)
        let arrivalTime = DateFormatters.timeFormatter.string(from: train.arrivalTime)
        let travelTime = DateFormatters.formatTravelTime(from: train.departureTime, to: train.arrivalTime)

        var trainInfo = "\(departureTime) → \(arrivalTime) [\(travelTime)] (\(train.trainChanges))"

        // Add platform numbers
        if train.trainChanges > 0 && train.allPlatforms.count > 1 {
            trainInfo += " (Pl. #\(train.allPlatforms.joined(separator: ", ")))"
        } else if !train.platform.isEmpty {
            trainInfo += " (Pl. #\(train.platform))"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trainInfo, forType: .string)
    }

    private func checkForExistingNotification() {
        let center = UNUserNotificationCenter.current()
        let notificationId = "train-\(train.trainNumber)-\(train.departureTime.timeIntervalSince1970)"

        center.getPendingNotificationRequests { requests in
            let exists = requests.contains { $0.identifier == notificationId }
            DispatchQueue.main.async {
                self.hasNotification = exists
            }
        }
    }

    private func removeNotification() {
        let center = UNUserNotificationCenter.current()
        let notificationId = "train-\(train.trainNumber)-\(train.departureTime.timeIntervalSince1970)"

        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        DispatchQueue.main.async {
            withAnimation {
                self.hasNotification = false
            }
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()

        // Request authorization if needed
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                // Calculate notification time considering walking duration
                let walkingTimeMin = PreferencesManager.shared.preferences.walkTimeDurationMin
                let notificationTime = train.departureTime.addingTimeInterval(-Double(walkingTimeMin * 60))

                // Only schedule if notification time is in the future
                let now = Date()
                guard notificationTime > now else {
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "Time to Leave!"

                // Get destination station name - look up the full name from station ID
                let toStationId = train.toStationName
                let toStation = Station.allStations.first(where: { $0.id == toStationId })?.name ?? toStationId

                // Build notification body
                var body = "Your train to \(toStation) departs at \(timeString(for: train.departureTime))"
                if !train.platform.isEmpty {
                    body += " from plat. \(train.platform)"
                }
                if walkingTimeMin > 0 {
                    body += " - start your \(walkingTimeMin) minute walk now"
                }

                content.body = body
                content.sound = .default

                // Calculate time interval from now
                let timeInterval = notificationTime.timeIntervalSinceNow
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "train-\(train.trainNumber)-\(train.departureTime.timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )

                center.add(request) { error in
                    if error == nil {
                        logInfo("Notification for train \(train.trainNumber) is set for time \(notificationTime)")
                        DispatchQueue.main.async {
                            withAnimation {
                                self.hasNotification = true
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HeaderView: View {
    let fromStationName: String
    let toStationName: String
    let isDirectionReversed: Bool
    let onReverseDirection: () -> Void
    let onSelectFavoriteRoute: (String) -> Void
    let favoriteRoutes: [FavoriteRoute]
    let stations: [Station]
    @State private var isRightDirection: Bool

    init(fromStationName: String, toStationName: String, isDirectionReversed: Bool, 
         favoriteRoutes: [FavoriteRoute] = [], stations: [Station] = [],
         onReverseDirection: @escaping () -> Void,
         onSelectFavoriteRoute: @escaping (String) -> Void = { _ in }) {
        self.fromStationName = fromStationName
        self.toStationName = toStationName
        self.isDirectionReversed = isDirectionReversed
        self.favoriteRoutes = favoriteRoutes
        self.stations = stations
        self.onReverseDirection = onReverseDirection
        self.onSelectFavoriteRoute = onSelectFavoriteRoute

        // Initialize the arrow direction based on the current direction state
        _isRightDirection = State(initialValue: !isDirectionReversed)
    }

    var body: some View {
        HStack {
            routeButton
            if !favoriteRoutes.isEmpty {
                favoritesMenu
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
    }

    private var routeButton: some View {
        Button(action: {
            isRightDirection.toggle()
            onReverseDirection()
        }) {
            HStack {
                Text("\(fromStationName)")
                    .lineLimit(1)
                Text(isRightDirection ? "→" : "←")
                    .foregroundStyle(.secondary)
                Text("\(toStationName)")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AccessoryBarButtonStyle())
        .help("\(fromStationName) \(isRightDirection ? "→" : "←") \(toStationName)")
    }

    private var favoritesMenu: some View {
        Menu {
            ForEach(favoriteRoutes) { route in
                Button {
                    onSelectFavoriteRoute(route.id)
                } label: {
                    let fromStationName = stations.first { $0.id == route.fromStation }?.name ?? route.fromStation
                    let toStationName = stations.first { $0.id == route.toStation }?.name ?? route.toStation

                    Text(route.name)
                        .help("\(fromStationName) \(route.isDirectionReversed ? "←" : "→") \(toStationName)")
                }
            }
        } label: {
            Image(systemName: "star")
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .frame(width: 20)
    }
}

// Shared component for consistent button styling
struct LinkButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    var isRefreshing: Bool = false
    
    init(icon: String, text: String, action: @escaping () -> Void, isRefreshing: Bool = false) {
        self.icon = icon
        self.text = text
        self.action = action
        self.isRefreshing = isRefreshing
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                if icon == "arrow.clockwise" && isRefreshing {
                    Image(systemName: "arrow.triangle.2.circlepath")
                } else {
                    Image(systemName: icon)
                }
                Text(text)
                    .font(.callout)
            }
        }
        .buttonStyle(LinkButtonStyle())
    }
}

// Shared menu component for both popover views
struct MoreMenuButton: View {
    let onAbout: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onAbout) {
                Label("About", systemImage: "info.circle")
            }
            
            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "ellipsis.circle")
                Text("More")
                    .font(.callout)
            }
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .buttonStyle(LinkButtonStyle())
    }
}

// Extension to conditionally apply modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .secondary.opacity(0.7) : .primary)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct TrainPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        let previewState = PopoverState()
        previewState.trainSchedules = [
            TrainSchedule(
                trainNumber: "123",
                departureTime: Date().addingTimeInterval(900), // 15 minutes from now
                arrivalTime: Date().addingTimeInterval(4500), // 75 minutes from now
                platform: "1",
                fromStationName: "Tel Aviv - Savidor",
                toStationName: "Haifa - Hof HaCarmel",
                trainChanges: 0,
                allTrainNumbers: ["123"],
                allPlatforms: ["1"]
            ),
            TrainSchedule(
                trainNumber: "456",
                departureTime: Date().addingTimeInterval(5400), // 90 minutes from now
                arrivalTime: Date().addingTimeInterval(9000), // 150 minutes from now
                platform: "2",
                fromStationName: "Tel Aviv - Savidor",
                toStationName: "Haifa - Hof HaCarmel",
                trainChanges: 1,
                allTrainNumbers: ["456", "789"],
                allPlatforms: ["2", "3"]
            )
        ]
        previewState.fromStationName = "Tel Aviv - Savidor"
        previewState.toStationName = "Haifa - Hof HaCarmel"
        previewState.isRefreshing = false

        return TrainPopoverView(state: previewState)
    }
}
