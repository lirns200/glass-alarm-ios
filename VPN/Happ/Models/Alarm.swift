import Foundation

enum VPNStatus {
    case disconnected, connecting, connected, error
}

struct VPNConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: String // VLESS, VMess, Trojan, Shadowsocks, Hysteria2
    var address: String
    var port: Int
    var uuid: String?
    var sni: String?
    var path: String?
    var security: String? // tls, reality, none
    var publicKey: String? // for reality
    var shortId: String? // for reality
    var flow: String? // xtls-rprx-vision etc.
    var ping: Int?
    var traffic: String?
    var flag: String
    
    init(id: UUID = UUID(), name: String, type: String, address: String, port: Int, flag: String = "🌐") {
        self.id = id
        self.name = name
        self.type = type
        self.address = address
        self.port = port
        self.flag = flag
    }
}
