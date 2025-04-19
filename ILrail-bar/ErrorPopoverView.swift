import SwiftUI

struct ErrorPopoverView: View {
    let errorMessage: String
    let fromStationName: String
    let toStationName: String
    let onReverseDirection: () -> Void
    let onRefresh: () -> Void
    let onPreferences: () -> Void
    let onWebsite: () -> Void
    let onAbout: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                fromStationName: fromStationName, 
                toStationName: toStationName, 
                onReverseDirection: onReverseDirection
            )
            
            Divider()
            
            // Error message
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
            .frame(height: 150)
            
            Divider()
            
            HStack(spacing: 15) {
                LinkButton(icon: "safari", text: "Website", action: onWebsite)
                                
                LinkButton(icon: "arrow.clockwise", text: "Refresh", action: onRefresh, keyboardShortcut: .init("r"))
                
                LinkButton(icon: "gear", text: "Prefs.", action: onPreferences, keyboardShortcut: .init(","))
                
                MoreMenuButton(onAbout: onAbout, onQuit: onQuit)
            }
            .padding()
        }
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ErrorPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorPopoverView(
            errorMessage: "No trains found for route",
            fromStationName: "Tel Aviv - Savidor",
            toStationName: "Haifa - Hof HaCarmel",
            onReverseDirection: {},
            onRefresh: {},
            onPreferences: {},
            onWebsite: {},
            onAbout: {},
            onQuit: {}
        )
    }
}