import Foundation

class VPNSubscriptionService {
    static let shared = VPNSubscriptionService()
    
    private init() {}
    
    func fetchSubscription(url: String, completion: @escaping (Result<[VPNConfig], Error>) -> Void) {
        guard let requestURL = URL(string: url) else {
            completion(.failure(NSError(domain: "VPNSubscriptionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue("v2rayN", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let base64String = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                completion(.failure(NSError(domain: "VPNSubscriptionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            let decodedString = self.decodeBase64(base64String) ?? base64String
            let configs = self.parseSubscriptionContent(decodedString)
            completion(.success(configs))
        }.resume()
    }
    
    func parseSubscriptionContent(_ content: String) -> [VPNConfig] {
        let cleanedData = content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r", with: "")
        
        var decodedContent: String = ""
        
        // Try Base64 decoding
        if let decodedData = Data(base64Encoded: cleanedData.replacingOccurrences(of: "\n", with: ""), options: .ignoreUnknownCharacters),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            decodedContent = decodedString
        } else {
            decodedContent = content
        }
        
        let lines = decodedContent.components(separatedBy: .newlines)
        var configs: [VPNConfig] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if let config = parseConfigLink(trimmed) {
                configs.append(config)
            }
        }
        
        return configs
    }
    
    func parseConfigLink(_ link: String) -> VPNConfig? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("vless://") {
            return parseVlessLink(trimmed)
        } else if trimmed.hasPrefix("vmess://") {
            return parseVmessLink(trimmed)
        } else if trimmed.hasPrefix("trojan://") {
            return parseTrojanLink(trimmed)
        }
        return nil
    }
    
    private func parseVlessLink(_ link: String) -> VPNConfig? {
        guard let url = URL(string: link),
              let host = url.host,
              let port = url.port else { return nil }
        
        let name = url.fragment?.removingPercentEncoding ?? "VLESS Server"
        let flag = self.detectFlag(from: name)
        
        var config = VPNConfig(name: name, type: "VLESS", address: host, port: port, flag: flag)
        config.uuid = url.user
        
        if let components = URLComponents(string: link),
           let queryItems = components.queryItems {
            config.security = queryItems.first(where: { $0.name == "security" })?.value
            config.sni = queryItems.first(where: { $0.name == "sni" })?.value
            config.publicKey = queryItems.first(where: { $0.name == "pbk" })?.value
            config.shortId = queryItems.first(where: { $0.name == "sid" })?.value
            config.flow = queryItems.first(where: { $0.name == "flow" })?.value
        }
        
        return config
    }
    
    private func parseVmessLink(_ link: String) -> VPNConfig? {
        let body = link.replacingOccurrences(of: "vmess://", with: "")
        guard let data = Data(base64Encoded: body, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        let name = json["ps"] as? String ?? "VMess Server"
        let address = json["add"] as? String ?? ""
        let port = Int("\(json["port"] ?? "443")") ?? 443
        let flag = self.detectFlag(from: name)
        
        var config = VPNConfig(name: name, type: "VMess", address: address, port: port, flag: flag)
        config.uuid = json["id"] as? String
        config.path = json["path"] as? String
        config.sni = json["sni"] as? String ?? json["host"] as? String
        config.security = json["tls"] as? String == "tls" ? "tls" : "none"
        
        return config
    }
    
    private func parseTrojanLink(_ link: String) -> VPNConfig? {
        guard let url = URL(string: link),
              let host = url.host,
              let port = url.port else { return nil }
        
        let name = url.fragment?.removingPercentEncoding ?? "Trojan Server"
        let flag = self.detectFlag(from: name)
        
        var config = VPNConfig(name: name, type: "Trojan", address: host, port: port, flag: flag)
        config.uuid = url.user
        
        if let components = URLComponents(string: link),
           let queryItems = components.queryItems {
            config.sni = queryItems.first(where: { $0.name == "sni" })?.value ?? queryItems.first(where: { $0.name == "peer" })?.value
            config.security = queryItems.first(where: { $0.name == "security" })?.value ?? "tls"
        }
        
        return config
    }

        }
        
        return configs
    }
    
    func parseConfigLink(_ link: String) -> VPNConfig? {
        if link.hasPrefix("vless://") {
            return parseVlessLink(link)
        } else if link.hasPrefix("vmess://") {
            return parseVmessLink(link)
        }
        // Add more protocol parsers as needed
        return nil
    }
    
    private func parseVlessLink(_ link: String) -> VPNConfig? {
        // vless://uuid@host:port?query#name
        guard let url = URL(string: link),
              let host = url.host,
              let port = url.port else { return nil }
        
        let name = url.fragment?.removingPercentEncoding ?? "VLESS Server"
        let flag = self.detectFlag(from: name)
        return VPNConfig(name: name, type: "VLESS", address: host, port: port, flag: flag)
    }
    
    private func detectFlag(from name: String) -> String {
        // First, try to find an existing emoji in the name
        if let firstEmoji = name.unicodeScalars.first(where: { $0.properties.isEmoji }) {
            return String(firstEmoji)
        }
        
        // Fallback to keyword search
        let nameLower = name.lowercased()
        if nameLower.contains("нидерланды") || nameLower.contains("netherlands") { return "🇳🇱" }
        if nameLower.contains("германия") || nameLower.contains("germany") { return "🇩🇪" }
        if nameLower.contains("франция") || nameLower.contains("france") { return "🇫🇷" }
        if nameLower.contains("россия") || nameLower.contains("russia") { return "🇷🇺" }
        if nameLower.contains("польша") || nameLower.contains("poland") { return "🇵🇱" }
        if nameLower.contains("финляндия") || nameLower.contains("finland") { return "🇫🇮" }
        if nameLower.contains("латвия") || nameLower.contains("latvia") { return "🇱🇻" }
        if nameLower.contains("великобритания") || nameLower.contains("uk") || nameLower.contains("britain") { return "🇬🇧" }
        
        return "🌐"
    }
    
    private func parseVmessLink(_ link: String) -> VPNConfig? {
        // vmess://base64(json)
        let base64 = String(link.dropFirst(8))
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        let name = json["ps"] as? String ?? "VMess Server"
        let address = json["add"] as? String ?? ""
        let port = Int(json["port"] as? String ?? "443") ?? 443
        let flag = self.detectFlag(from: name)
        
        return VPNConfig(name: name, type: "VMess", address: address, port: port, flag: flag)
    }
    
    private func decodeBase64(_ base64: String) -> String? {
        var st = base64
        let remainder = st.count % 4
        if remainder > 0 {
            st = st.padding(toLength: st.count + (4 - remainder), withPad: "=", startingAt: 0)
        }
        guard let data = Data(base64Encoded: st, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
