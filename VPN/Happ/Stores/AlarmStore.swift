import SwiftUI

class AlarmStore: ObservableObject {
    static let shared = AlarmStore()
    
    @Published var configs: [VPNConfig] = [] {
        didSet {
            save()
        }
    }
    
    private let saveKey = "saved_vpn_configs"
    
    init() {
        load()
    }
    
    func add(config: VPNConfig) {
        if !configs.contains(where: { $0.address == config.address && $0.port == config.port }) {
            configs.append(config)
        }
    }
    
    func removeAll() {
        configs.removeAll()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([VPNConfig].self, from: data) {
            configs = decoded
        }
    }
}
