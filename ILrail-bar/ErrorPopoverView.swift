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
            // Header with station names and reverse button
            Button(action: onReverseDirection) {
                HStack {
                    Text("\(fromStationName) → \(toStationName)")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding([.horizontal, .top])
            .padding(.bottom, 5)
            .help("Click to reverse direction")
            
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
            
            // Action buttons
            HStack(spacing: 15) {
                Button(action: onWebsite) {
                    HStack(spacing: 3) {
                        Image(systemName: "safari")
                        Text("Website")
                            .font(.callout)
                    }
                }
                .buttonStyle(LinkButtonStyle())
                
                Spacer()
                
                Button(action: onRefresh) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                            .font(.callout)
                    }
                }
                .buttonStyle(LinkButtonStyle())
                .keyboardShortcut("r")
                
                Button(action: onPreferences) {
                    HStack(spacing: 3) {
                        Image(systemName: "gear")
                        Text("Preferences")
                            .font(.callout)
                    }
                }
                .buttonStyle(LinkButtonStyle())
                .keyboardShortcut(",")
                
                Menu {
                    Button(action: onAbout) {
                        Label("About", systemImage: "info.circle")
                    }
                    
                    Button(action: onQuit) {
                        Label("Quit", systemImage: "power")
                    }
                    .keyboardShortcut("q")
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.callout)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .fixedSize()
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