import SwiftUI

struct ErrorPopoverView: View {
    @ObservedObject var state: PopoverState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            // Error message
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    if let errorMessage = state.errorMessage {
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
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
            .frame(height: 180)
            
            Divider()
            
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
    }
}

struct ErrorPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        let previewState = PopoverState()
        previewState.errorMessage = "No trains found for route"
        previewState.fromStationName = "Tel Aviv - Savidor"
        previewState.toStationName = "Haifa - Hof HaCarmel"
        previewState.isRefreshing = false

        return ErrorPopoverView(state: previewState)
    }
}
