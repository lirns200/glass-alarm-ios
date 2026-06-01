import SwiftUI

struct DashboardView: View {
    @ObservedObject private var vpnManager = VPNManager.shared
    @State private var sessionTime: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header / Status
                VStack(spacing: 5) {
                    Text(vpnManager.status == .connected ? "CONNECTED" : "NOT CONNECTED")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(statusColor.opacity(0.8))
                    
                    if let config = vpnManager.selectedConfig {
                        Text("\(config.type) • \(timeString(from: sessionTime))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Central Connect Button
                Button {
                    toggleConnection()
                } label: {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 180, height: 180)
                        
                        Image(systemName: "power")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(statusColor)
                            .shadow(color: statusColor.opacity(0.5), radius: 10)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Server Card (Current)
                if let config = vpnManager.selectedConfig {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(config.flag)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(config.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(config.address)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(config.ping ?? 0) ms")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.green)
                                Text("↑ 0 KB/s")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(white: 0.08))
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                } else {
                    Text("Select a server to connect")
                        .foregroundStyle(.gray)
                        .padding(.bottom, 20)
                }
                
                Spacer().frame(height: 20)
            }
        }
        .onReceive(timer) { _ in
            if vpnManager.status == .connected {
                sessionTime += 1
            }
        }
    }
    
    private var statusColor: Color {
        switch vpnManager.status {
        case .disconnected: return .gray
        case .connecting: return .blue
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private func toggleConnection() {
        withAnimation(.spring()) {
            if vpnManager.status == .disconnected {
                if let config = vpnManager.selectedConfig {
                    vpnManager.connect(config: config)
                } else {
                    // Default config or error
                    print("No config selected")
                }
            } else {
                vpnManager.disconnect()
                sessionTime = 0
            }
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
