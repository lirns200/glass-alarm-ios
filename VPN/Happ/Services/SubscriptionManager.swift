import Foundation

class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    func parse(link: String) -> [VPNConfig] {
        var configs: [VPNConfig] = []
        
        // Handle subscription URL (http/https)
        if link.starts(with: "http") {
            // This would normally fetch the URL. For now, we return empty
            // because async network calls are handled in the ViewModel/Store.
            return []
        }
        
        // Handle single configs
        if let config = parseSingle(link: link) {
            configs.append(config)
        }
        
        return configs
    }
    
    func parseSingle(link: String) -> VPNConfig? {
        if link.starts(with: "vless://") {
            return parseVLESS(link: link)
        } else if link.starts(with: "vmess://") {
            return parseVMess(link: link)
        } else if link.starts(with: "trojan://") {
            return parseTrojan(link: link)
        }
        return nil
    }
    
    func decodeSubscription(_ data: String) -> [VPNConfig] {
        // Base64 or plain text list of links
        let content: String
        if let decodedData = Data(base64Encoded: data.trimmingCharacters(in: .whitespacesAndNewlines)),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            content = decodedString
        } else {
            content = data
        }
        
        let lines = content.components(separatedBy: .newlines)
        return lines.compactMap { parseSingle(link: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    
    private func parseTrojan(link: String) -> VPNConfig? {
        guard let url = URL(string: link),
              let host = url.host,
              let port = url.port else { return nil }
        
        let config = VPNConfig(name: url.fragment ?? "Trojan Server", 
                               type: "Trojan", 
                               address: host, 
                               port: port)
        return config
    }
        // vless://uuid@host:port?security=reality&sni=google.com&fp=chrome&pbk=xxx&sid=xxx#name
        guard let url = URL(string: link),
              let host = url.host,
              let port = url.port else { return nil }
        
        var config = VPNConfig(name: url.fragment ?? "VLESS Server", 
                               type: "VLESS", 
                               address: host, 
                               port: port)
        
        config.uuid = url.user
        
        if let components = URLComponents(string: link),
           let queryItems = components.queryItems {
            config.security = queryItems.first(where: { $0.name == "security" })?.value
            config.sni = queryItems.first(where: { $0.name == "sni" })?.value
            config.publicKey = queryItems.first(where: { $0.name == "pbk" })?.value
            config.shortId = queryItems.first(where: { $0.name == "sid" })?.value
        }
        
        return config
    }
    
    private func parseVMess(link: String) -> VPNConfig? {
        // vmess://base64(json)
        let body = link.replacingOccurrences(of: "vmess://", with: "")
        guard let data = Data(base64Encoded: body),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        let name = json["ps"] as? String ?? "VMess Server"
        let host = json["add"] as? String ?? ""
        let portString = json["port"] as? String ?? "443"
        let port = Int(portString) ?? 443
        
        var config = VPNConfig(name: name, type: "VMess", address: host, port: port)
        config.uuid = json["id"] as? String
        config.path = json["path"] as? String
        config.security = json["tls"] as? String == "tls" ? "tls" : "none"
        
        return config
    }
}
