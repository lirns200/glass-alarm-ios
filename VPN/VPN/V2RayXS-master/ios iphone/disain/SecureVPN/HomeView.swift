import SwiftUI

struct HomeView: View {
    @Binding var selectedServer: Server
    @StateObject private var vpnManager = VPNManager.shared
    @State private var isPulsing = false
    @State private var waveAnimation = false
    
    // Преобразование статуса системы в наш UI статус
    var uiState: VPNState {
        switch vpnManager.status {
        case .connected: return .connected
        case .connecting, .reasserting: return .connecting
        default: return .disconnected
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color(red: 0.1, green: 0.1, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                HStack {
                    Text("SecureVPN")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                ZStack {
                    if uiState != .disconnected {
                        Circle()
                            .stroke(uiState.color.opacity(0.5), lineWidth: 2)
                            .frame(width: 200, height: 200)
                            .scaleEffect(waveAnimation ? 2.0 : 1.0)
                            .opacity(waveAnimation ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: waveAnimation)
                        
                        Circle()
                            .stroke(uiState.color.opacity(0.3), lineWidth: 2)
                            .frame(width: 200, height: 200)
                            .scaleEffect(waveAnimation ? 2.5 : 1.0)
                            .opacity(waveAnimation ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(0.5), value: waveAnimation)
                    }
                    
                    Button(action: toggleVPN) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [uiState.color.opacity(0.8), uiState.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 180, height: 180)
                                .shadow(color: uiState.color.opacity(0.5), radius: uiState == .disconnected ? 0 : 20, x: 0, y: 10)
                                .scaleEffect(isPulsing ? 0.95 : 1.0)
                            
                            Image(systemName: "power")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text(uiState.title)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .animation(.easeInOut, value: uiState)
                
                Spacer()
                
                ServerSelectionCard(server: selectedServer)
                
                Spacer().frame(height: 20)
            }
        }
        .onAppear {
            waveAnimation = true
        }
    }
    
    private func toggleVPN() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPulsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPulsing = false }
        }
        
        if uiState == .disconnected {
            // Реальный вызов сетевого расширения
            vpnManager.connect()
        } else {
            // Остановка
            vpnManager.disconnect()
        }
    }
}

struct ServerSelectionCard: View {
    var server: Server
    var body: some View {
        HStack {
            Text(server.flag)
                .font(.title)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(server.country), \(server.city)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(server.isPremium ? "Premium • \(server.ping)ms" : "Free • \(server.ping)ms")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.1))
                .background(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.2), lineWidth: 1))
        )
        .padding(.horizontal, 30)
    }
}
