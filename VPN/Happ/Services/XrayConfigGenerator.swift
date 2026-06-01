import Foundation

class XrayConfigGenerator {
    static func generate(for config: VPNConfig) -> [String: Any] {
        var outbound: [String: Any] = [
            "protocol": config.type.lowercased(),
            "settings": [
                "vnext": [
                    [
                        "address": config.address,
                        "port": config.port,
                        "users": [
                            [
                                "id": config.uuid ?? "",
                                "flow": config.flow ?? "",
                                "encryption": "none",
                                "level": 0
                            ]
                        ]
                    ]
                ]
            ],
            "streamSettings": [
                "network": "tcp",
                "security": config.security ?? "none"
            ]
        ]
        
        if config.security == "reality" {
            outbound["streamSettings"] = [
                "network": "tcp",
                "security": "reality",
                "realitySettings": [
                    "show": false,
                    "fingerprint": "chrome",
                    "serverName": config.sni ?? "",
                    "publicKey": config.publicKey ?? "",
                    "shortId": config.shortId ?? "",
                    "spiderX": "/"
                ]
            ]
        } else if config.security == "tls" {
            outbound["streamSettings"] = [
                "network": "tcp",
                "security": "tls",
                "tlsSettings": [
                    "serverName": config.sni ?? "",
                    "allowInsecure": false
                ]
            ]
        }
        
        let fullConfig: [String: Any] = [
            "log": ["loglevel": "warning"],
            "inbounds": [
                [
                    "port": 10808,
                    "protocol": "socks",
                    "settings": ["auth": "noauth", "udp": true]
                ]
            ],
            "outbounds": [outbound]
        ]
        
        return fullConfig
    }
}
