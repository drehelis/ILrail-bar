import SwiftUI

// A simple SwiftUI view for the About dialog
struct AboutView: View {
    let window: NSWindow
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "tram.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
            
            GroupBox(label: 
                Text("Legend:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 5) {
                        Text("[minutes]")
                            .fontWeight(.medium)
                        Text("- Travel time")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 5) {
                        Text("(#)")
                            .fontWeight(.medium)
                        Text("- Train number")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 5) {
                        Text("(0)")
                            .fontWeight(.medium)
                        Text("- No train changes required")
                    }
                    
                    HStack(spacing: 5) {
                        Text("(1+)")
                            .fontWeight(.medium)
                        Text("- Train changes required")
                    }
                }
                .padding(8)
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 30) {
                Button(action: {
                    if let url = URL(string: "https://github.com/drehelis/ILrail-bar") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Github")
                        .font(.headline)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    if let url = URL(string: "https://linkedin.com/in/drehelis") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("LinkedIn")
                        .font(.headline)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .frame(width: 350, height: 350)
    }
}
