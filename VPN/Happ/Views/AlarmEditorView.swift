import SwiftUI

struct AlarmEditorView: View {
    @State private var url: String = ""
    @State private var configs: [VPNConfig] = [
        VPNConfig(name: "Warsaw Premium", type: "VLESS", address: "2.26.5.82", port: 443, flag: "🇵🇱"),
        VPNConfig(name: "Frankfurt Auto", type: "VMess", address: "de1.yuku.vpn", port: 8080, flag: "🇩🇪")
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Import from Clipboard
                Button {
                    importFromClipboard()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // List of Configs
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(configs) { config in
                            HStack {
                                Text(config.flag)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(config.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text(config.type)
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .padding()
                            .background(Color(white: 0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Subscriptions")
    }
    
    private func importFromClipboard() {
        #if os(iOS)
        if let string = UIPasteboard.general.string {
            // Basic parsing logic would go here
            print("Importing: \(string)")
        }
        #endif
    }
}
