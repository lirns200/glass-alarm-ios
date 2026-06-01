import SwiftUI

class AlarmStore: ObservableObject {
    static let shared = AlarmStore()
    
    @Published var configs: [VPNConfig] = [] {
        didSet {
            save()
        }
    }
    
    init() {
        load()
    }
    
    func add(config: VPNConfig) {
        configs.append(config)
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: "vpn_configs")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "vpn_configs"),
           let decoded = try? JSONDecoder().decode([VPNConfig].self, from: data) {
            self.configs = decoded
        }
    }
}
