import SwiftUI

struct TrainPopoverView: View {
    let trainSchedules: [TrainSchedule]
    let fromStationName: String
    let toStationName: String
    let isRefreshing: Bool
    let onReverseDirection: () -> Void
    let onRefresh: () -> Void
    let onPreferences: () -> Void
    let onWebsite: () -> Void
    let onAbout: () -> Void
    let onQuit: () -> Void
    
    private let redAlertMinutes: Int
    private let blueAlertMinutes: Int
    
    init(trainSchedules: [TrainSchedule], 
         fromStationName: String,
         toStationName: String,
         preferences: StationPreferences,
         isRefreshing: Bool = false,
         onReverseDirection: @escaping () -> Void,
         onRefresh: @escaping () -> Void,
         onPreferences: @escaping () -> Void,
         onWebsite: @escaping () -> Void,
         onAbout: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.trainSchedules = trainSchedules
        self.fromStationName = fromStationName
        self.toStationName = toStationName
        self.isRefreshing = isRefreshing
        self.onReverseDirection = onReverseDirection
        self.onRefresh = onRefresh
        self.onPreferences = onPreferences
        self.onWebsite = onWebsite
        self.onAbout = onAbout
        self.onQuit = onQuit
        self.redAlertMinutes = preferences.redAlertMinutes
        self.blueAlertMinutes = preferences.blueAlertMinutes
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with station names and reverse button
            HeaderView(
                fromStationName: fromStationName,
                toStationName: toStationName,
                onReverseDirection: onReverseDirection,
                isFromCache: trainSchedules.first?.isFromCache ?? false,
                cacheAgeMinutes: trainSchedules.first?.cacheAgeMinutes
            )
            
            Divider()
            
            // Next train section
            if !trainSchedules.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Next:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                        
                    TrainInfoRow(
                        train: trainSchedules[0],
                        redAlertMinutes: redAlertMinutes,
                        blueAlertMinutes: blueAlertMinutes
                    )
                    
                    // Upcoming trains
                    if trainSchedules.count > 1 {
                        Divider()
                            .padding(.vertical, 5)
                        
                        Text("Upcoming:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                            
                        // Only show configured number of trains
                        let maxItems = min(trainSchedules.count, PreferencesManager.shared.preferences.upcomingItemsCount + 1)
                        ForEach(1..<maxItems, id: \.self) { index in
                            TrainInfoRow(
                                train: trainSchedules[index],
                                redAlertMinutes: redAlertMinutes,
                                blueAlertMinutes: blueAlertMinutes
                            )
                            
                            if index < maxItems - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 5)
                
                Divider()
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    Text("No trains found for this route")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 100)
                
                Divider()
            }
            
            HStack(spacing: 15) {
                LinkButton(icon: "safari", text: "Website", action: onWebsite)
                
                LinkButton(
                    icon: "arrow.clockwise", 
                    text: isRefreshing ? "Loading" : "Refresh ", 
                    action: onRefresh, 
                    isRefreshing: isRefreshing
                )
                                
                LinkButton(icon: "gear", text: "Prefs.", action: onPreferences)
                                
                MoreMenuButton(onAbout: onAbout, onQuit: onQuit)
            }
            .padding()
        }
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TrainInfoRow: View {
    let train: TrainSchedule
    let redAlertMinutes: Int
    let blueAlertMinutes: Int
    
    @State private var isCopied: Bool = false
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
                            .foregroundColor(timeUntilDepartureColor())
                            .id("departure-\(refreshID)")
                        
                        Text("→")
                            .foregroundStyle(.secondary)
                        
                        Text(timeString(for: train.arrivalTime))
                            .font(.system(.body, design: .default).monospacedDigit())
                            .fontWeight(.medium)
                            .foregroundColor(timeUntilDepartureColor())
                            .id("arrival-\(refreshID)")
                        
                        Spacer(minLength: 4)
                        
                        Group {
                            Text("[\(travelTimeString())]")
                                .font(.system(.caption, design: .default).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .id("travel-\(refreshID)")
                            
                            if train.trainChanges > 0 && !train.allTrainNumbers.isEmpty {
                                Text("(\(train.allTrainNumbers.map { "#\($0)" }.joined(separator: ", ")))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if !train.trainNumber.isEmpty {
                                Text("(#\(train.trainNumber))")
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
            .contentShape(Rectangle())
            .padding(.horizontal)
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onReceive(NotificationCenter.default.publisher(for: .trainDisplayUpdate)) { _ in
            refreshID = UUID()
        }
    }
    
    private func timeUntilDepartureColor() -> Color {
        let timeUntilDepartureSeconds = train.departureTime.timeIntervalSinceNow
        let timeUntilDepartureMinutes = timeUntilDepartureSeconds / 60
        
        if timeUntilDepartureMinutes <= Double(redAlertMinutes) {
            return Color.red
        } else if timeUntilDepartureMinutes <= Double(blueAlertMinutes) {
            return Color.blue
        } else {
            return Color.primary
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
        
        // Add train numbers
        if train.trainChanges > 0 && !train.allTrainNumbers.isEmpty {
            trainInfo += " (\(train.allTrainNumbers.map { "#\($0)" }.joined(separator: ", ")))"
        } else if !train.trainNumber.isEmpty {
            trainInfo += " (#\(train.trainNumber))"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trainInfo, forType: .string)
    }
}

struct HeaderView: View {
    let fromStationName: String
    let toStationName: String
    let onReverseDirection: () -> Void
    let isFromCache: Bool
    let cacheAgeMinutes: Int?
    
    var body: some View {
        VStack(spacing: 3) {
            Button(action: onReverseDirection) {
                HStack {
                    Text("\(fromStationName) → \(toStationName)")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(AccessoryBarButtonStyle())
            .help("\(fromStationName) → \(toStationName)")
            
            if isFromCache, let cacheAge = cacheAgeMinutes {
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Text("Fetched \(cacheAge)m ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 0))
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
        TrainPopoverView(
            trainSchedules: [
                TrainSchedule(
                    trainNumber: "123",
                    departureTime: Date().addingTimeInterval(900), // 15 minutes from now
                    arrivalTime: Date().addingTimeInterval(4500), // 75 minutes from now
                    platform: "1",
                    fromStationName: "Tel Aviv - Savidor",
                    toStationName: "Haifa - Hof HaCarmel",
                    trainChanges: 0,
                    allTrainNumbers: ["123"],
                    isFromCache: true,
                    cacheAgeMinutes: 15
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
                    isFromCache: true,
                    cacheAgeMinutes: 15
                )
            ],
            fromStationName: "Tel Aviv - Savidor",
            toStationName: "Haifa - Hof HaCarmel",
            preferences: StationPreferences.defaultPreferences,
            isRefreshing: false,
            onReverseDirection: {},
            onRefresh: {},
            onPreferences: {},
            onWebsite: {},
            onAbout: {},
            onQuit: {}
        )
    }
}
