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
        let decodedLink = link.removingPercentEncoding ?? link
        if decodedLink.starts(with: "vless://") {
            return parseVLESS(link: link)
        } else if decodedLink.starts(with: "vmess://") {
            return parseVMess(link: link)
        } else if decodedLink.starts(with: "trojan://") {
            return parseTrojan(link: link)
        }
        return nil
    }

    private func parseVLESS(link: String) -> VPNConfig? {
        guard let components = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        
        let host = components.host ?? ""
        let port = components.port ?? 443
        let name = components.fragment?.removingPercentEncoding ?? "VLESS Server"
        
        // Try to extract flag from name
        var flag = "🌐"
        if let firstEmoji = name.unicodeScalars.first(where: { $0.properties.isEmoji }) {
            flag = String(firstEmoji)
        }
        
        var config = VPNConfig(name: name, 
                               type: "VLESS", 
                               address: host, 
                               port: port,
                               flag: flag)
        
        config.uuid = components.user
...
    private func parseTrojan(link: String) -> VPNConfig? {
        guard let components = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        
        let host = components.host ?? ""
        let port = components.port ?? 443
        let name = components.fragment?.removingPercentEncoding ?? "Trojan Server"
        
        var flag = "🌐"
        if let firstEmoji = name.unicodeScalars.first(where: { $0.properties.isEmoji }) {
            flag = String(firstEmoji)
        }
        
        var config = VPNConfig(name: name, 
                               type: "Trojan", 
                               address: host, 
                               port: port,
                               flag: flag)
        config.uuid = components.user
        return config
    }

        
        return config
    }

        return nil
    }
    
    func decodeSubscription(_ data: String) -> [VPNConfig] {
        let cleanedData = data.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        
        var content: String = ""
        
        // Try Base64 decoding first
        if let decodedData = Data(base64Encoded: cleanedData),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            content = decodedString
        } else {
            // Fallback: try adding padding if needed
            let padded = cleanedData.padding(toLength: ((cleanedData.count + 3) / 4) * 4, 
                                            withPad: "=", 
                                            startingAt: 0)
            if let decodedData = Data(base64Encoded: padded),
               let decodedString = String(data: decodedData, encoding: .utf8) {
                content = decodedString
            } else {
                // If Base64 fails, assume it's already plaintext (e.g. list of links)
                content = data
            }
        }
        
        let lines = content.components(separatedBy: .whitespacesAndNewlines)
        return lines.filter { !$0.isEmpty }.compactMap { parseSingle(link: $0) }
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
