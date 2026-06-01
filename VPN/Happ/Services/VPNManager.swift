import Foundation
import Combine
import NetworkExtension

class VPNManager: ObservableObject {
    static let shared = VPNManager()
    
    @Published var status: VPNStatus = .disconnected
    @Published var selectedConfig: VPNConfig?
    
    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: AnyCancellable?
    
    private init() {
        refreshManager()
    }
    
    func refreshManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            self?.tunnelManager = managers?.first
            self?.observeStatus()
        }
    }
    
    private func observeStatus() {
        statusObserver?.cancel()
        guard let manager = tunnelManager else { return }
        
        statusObserver = NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)
            .sink { [weak self] _ in
                self?.updateStatus()
            }
        updateStatus()
    }
    
    private func updateStatus() {
        guard let manager = tunnelManager else {
            status = .disconnected
            return
        }
        
        switch manager.connection.status {
        case .connected: status = .connected
        case .connecting, .reasserting: status = .connecting
        case .disconnecting: status = .connecting
        case .disconnected, .invalid: status = .disconnected
        @unknown default: status = .disconnected
        }
    }
    
    func connect(config: VPNConfig) {
        self.selectedConfig = config
        
        if tunnelManager == nil {
            setupManager { [weak self] success in
                if success {
                    self?.startTunnel(with: config)
                } else {
                    self?.status = .error
                }
            }
        } else {
            startTunnel(with: config)
        }
    }
    
    private func setupManager(completion: @escaping (Bool) -> Void) {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "GlassAlarm VPN"
        
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = "com.yuku.GlassAlarm.PacketTunnel" // This should match your extension bundle ID
        protocolConfiguration.serverAddress = "GlassAlarm-VPN"
        
        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true
        
        manager.saveToPreferences { error in
            if let error = error {
                print("Failed to save VPN preferences: \(error)")
                completion(false)
            } else {
                manager.loadFromPreferences { error in
                    self.tunnelManager = manager
                    self.observeStatus()
                    completion(error == nil)
                }
            }
        }
    }
    
    private func startTunnel(with config: VPNConfig) {
        guard let manager = tunnelManager else { return }
        
        manager.loadFromPreferences { [weak self] error in
            guard error == nil else {
                self?.status = .error
                return
            }
            
            manager.isEnabled = true
            manager.saveToPreferences { error in
                guard error == nil else {
                    self?.status = .error
                    return
                }
                
                let options: [String: NSObject] = [
                    "config": self?.serializeConfig(config) as? NSObject ?? "" as NSObject
                ]
                
                do {
                    try manager.connection.startVPNTunnel(options: options)
                } catch {
                    print("Failed to start tunnel: \(error)")
                    self?.status = .error
                }
            }
        }
    }
    
    func disconnect() {
        tunnelManager?.connection.stopVPNTunnel()
    }
    
    private func serializeConfig(_ config: VPNConfig) -> String {
        if let data = try? JSONEncoder().encode(config),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return ""
    }
}
