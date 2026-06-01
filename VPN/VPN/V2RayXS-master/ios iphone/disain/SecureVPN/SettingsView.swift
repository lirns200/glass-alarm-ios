import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var killSwitchEnabled = false
    @State private var protocolSelection = "Auto"
    
    let protocols = ["Auto", "WireGuard", "OpenVPN", "IKEv2"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection")) {
                    Picker("Protocol", selection: $protocolSelection) {
                        ForEach(protocols, id: \.self) {
                            Text($0)
                        }
                    }
                    
                    Toggle("Kill Switch", isOn: $killSwitchEnabled)
                        .tint(.orange)
                }
                
                Section(header: Text("General")) {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                        .tint(.orange)
                    
                    Button("Restore Purchases") {
                        // action
                    }
                    .foregroundColor(.orange)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    Button("Privacy Policy") {}
                    Button("Terms of Service") {}
                }
            }
            .navigationTitle("Settings")
        }
    }
}
