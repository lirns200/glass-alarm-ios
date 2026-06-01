import SwiftUI

struct ContentView: View {
    @State private var selectedServer: Server = Server(country: "Germany", city: "Frankfurt", flag: "🇩🇪", ping: 12, isPremium: true)
    
    var body: some View {
        TabView {
            HomeView(selectedServer: $selectedServer)
                .tabItem {
                    Image(systemName: "shield.fill")
                    Text("VPN")
                }
                
            ServerListView(selectedServer: $selectedServer)
                .tabItem {
                    Image(systemName: "network")
                    Text("Servers")
                }
                
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .accentColor(.orange)
        .preferredColorScheme(.dark)
    }
}
