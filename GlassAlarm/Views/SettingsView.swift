import SwiftUI

struct SettingsView: View {
    @AppStorage("routing_mode") private var routingMode = "Global"
    @AppStorage("enable_ipv6") private var enableIPv6 = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            List {
                Section(header: Text("Routing").foregroundStyle(.gray)) {
                    Picker("Mode", selection: $routingMode) {
                        Text("Global").tag("Global")
                        Text("Bypass LAN").tag("Bypass LAN")
                        Text("Smart (GeoData)").tag("Smart")
                    }
                    .listRowBackground(Color(white: 0.05))
                }
                
                Section(header: Text("Network").foregroundStyle(.gray)) {
                    Toggle("Enable IPv6", isOn: $enableIPv6)
                        .listRowBackground(Color(white: 0.05))
                }
                
                Section(header: Text("About").foregroundStyle(.gray)) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0 (Xray 26.3.27)")
                            .foregroundStyle(.gray)
                    }
                    .listRowBackground(Color(white: 0.05))
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}
