import SwiftUI

struct SaveRouteView: View {
    @Binding var isPresented: Bool
    let stations: [Station]
    let onSave: (String) -> Void
    let initialRouteName: String
    
    @State private var routeName: String
    
    init(isPresented: Binding<Bool>, stations: [Station], initialRouteName: String = "", onSave: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.stations = stations
        self.onSave = onSave
        self.initialRouteName = initialRouteName
        self._routeName = State(initialValue: initialRouteName)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Route Name (e.g. Home, Work)", text: $routeName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    if !routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave(routeName.trimmingCharacters(in: .whitespacesAndNewlines))
                        isPresented = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 300)
    }
}

struct ManageFavoritesView: View {
    @Binding var isPresented: Bool
    let stations: [Station]
    let onRoutesChanged: () -> Void
    
    @State private var favoriteRoutes: [FavoriteRoute]
    
    init(isPresented: Binding<Bool>, stations: [Station], onRoutesChanged: @escaping () -> Void = {}) {
        self._isPresented = isPresented
        self.stations = stations
        self.onRoutesChanged = onRoutesChanged
        self._favoriteRoutes = State(initialValue: PreferencesManager.shared.preferences.favoriteRoutes)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if favoriteRoutes.isEmpty {
                Text("No saved routes")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(favoriteRoutes) { route in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.name)
                                    .fontWeight(.medium)
                                
                                let fromStation = stations.first { $0.id == route.fromStation }?.name ?? route.fromStation
                                let toStation = stations.first { $0.id == route.toStation }?.name ?? route.toStation
                                
                                Text("\(fromStation) \(route.isDirectionReversed ? "←" : "→") \(toStation)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                deleteRoute(route)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(width: 340, height: min(CGFloat(favoriteRoutes.count * 50), 200))
            }
            
            HStack(spacing: 16) {
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 360)
    }
    
    private func deleteRoute(_ route: FavoriteRoute) {
        PreferencesManager.shared.deleteFavoriteRoute(id: route.id)
        
        // Update the local array
        favoriteRoutes = PreferencesManager.shared.preferences.favoriteRoutes
        onRoutesChanged()
    }
}
