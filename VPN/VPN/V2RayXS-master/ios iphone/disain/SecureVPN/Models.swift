import Foundation
import SwiftUI

// Состояния нашего VPN
enum VPNState {
    case disconnected
    case connecting
    case connected
    
    var title: String {
        switch self {
        case .disconnected: return "Tap to Connect"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return Color.gray.opacity(0.8)
        case .connecting: return Color.orange
        case .connected: return Color.green
        }
    }
}

// Модель сервера (ноды)
struct Server: Identifiable, Hashable {
    let id = UUID()
    let country: String
    let city: String
    let flag: String
    let ping: Int
    let isPremium: Bool
    
    // Детали для Xray
    var address: String = "example.com"
    var port: Int = 443
    var uuid: String = ""
}

// Поддерживаемые протоколы из V2RayXS
enum ProxyProtocol: String, CaseIterable, Identifiable {
    case vless = "VLESS (XTLS)"
    case vmess = "VMess"
    case trojan = "Trojan"
    case shadowsocks = "Shadowsocks"
    case wireguard = "Wireguard"
    case socks = "Socks5"
    case auto = "Auto"
    
    var id: String { self.rawValue }
}
