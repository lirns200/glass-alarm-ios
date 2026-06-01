import Foundation

enum VPNStatus {
    case disconnected, connecting, connected, error
}

struct VPNConfig: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: String // VLESS, VMess, etc.
    let address: String
    let port: Int
    var ping: Int?
    var traffic: String?
    let flag: String // Emoji flag
    
    init(id: UUID = UUID(), name: String, type: String, address: String, port: Int, flag: String = "🌐") {
        self.id = id
        self.name = name
        self.type = type
        self.address = address
        self.port = port
        self.flag = flag
    }
}
