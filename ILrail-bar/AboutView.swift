import SwiftUI

struct AboutView: View {
    let window: NSWindow
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "tram.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                
                Text("ILrail-bar")
                    .font(.system(size: 24, weight: .bold))
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Legend")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Divider()
                    
                    LegendItem(symbol: "[minutes]", description: "Travel time")
                    LegendItem(symbol: "(Plat. #)", description: "Platform number")
                    LegendItem(symbol: "(0)", description: "No train changes required")
                    LegendItem(symbol: "(1+)", description: "Train changes required")
                }
                .padding(8)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 16) {
                Divider()
                
                HStack(spacing: 12) {
                    AboutLinkButton(
                        title: "GitHub",
                        icon: "link.circle.fill",
                        url: "https://github.com/drehelis/ILrail-bar"
                    )
                    
                    AboutLinkButton(
                        title: "LinkedIn",
                        icon: "person.circle.fill",
                        url: "https://linkedin.com/in/drehelis"
                    )
                    
                    AboutLinkButton(
                        title: "BuyMeCoffee",
                        icon: "cup.and.saucer.fill",
                        url: "https://www.buymeacoffee.com/drehelis"
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(width: 350, height: 400)
        .background(
            Color(NSColor.windowBackgroundColor)
                .opacity(0.6)
        )
    }
}

struct LegendItem: View {
    let symbol: String
    let description: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(symbol)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 70, alignment: .leading)
            
            Text(description)
                .foregroundColor(.secondary)
        }
    }
}

struct AboutLinkButton: View {
    let title: String
    let icon: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
        }
        .buttonStyle(AboutLinkButtonStyle())
    }
}

struct AboutLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .blue.opacity(0.7) : .blue)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(configuration.isPressed ? 0.1 : 0.05))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
