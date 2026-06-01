import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var killSwitchEnabled = false
    @State private var selectedProtocol: ProxyProtocol = .vless
    
    @State private var routingMode = "Global"
    let routingModes = ["Global", "PAC", "Tun Mode (All Traffic)"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Core / Protocols (Xray-core)")) {
                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach(ProxyProtocol.allCases) { protocolType in
                            Text(protocolType.rawValue).tag(protocolType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Routing Mode", selection: $routingMode) {
                        ForEach(routingModes, id: \.self) {
                            Text($0)
                        }
                    }
                    
                    Toggle("Kill Switch (Block internet on drop)", isOn: $killSwitchEnabled)
                        .tint(.orange)
                }
                
                Section(header: Text("Advanced Setup")) {
                    NavigationLink(destination: Text("JSON Config Editor (Like in V2RayXS)")) {
                        Text("Edit Outbounds JSON")
                    }
                    NavigationLink(destination: Text("Subscription URL settings")) {
                        Text("Manage Subscriptions")
                    }
                }
                
                Section(header: Text("General")) {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                        .tint(.orange)
                    
                    Button("Restore Purchases") {
                        // action
                    }
                    .foregroundColor(.orange)
                }
                
                Section(header: Text("About Xray-iOS")) {
                    HStack {
                        Text("Core Version")
                        Spacer()
                        Text("Xray-core 1.8.x")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
