import Foundation
import NetworkExtension

class VPNManager: ObservableObject {
    static let shared = VPNManager()
    
    @Published var status: NEVPNStatus = .invalid
    private var manager: NETunnelProviderManager?
    
    init() {
        loadVPNConfiguration()
    }
    
    // Загружаем настройки VPN из системы
    func loadVPNConfiguration() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Ошибка загрузки VPN: \(error.localizedDescription)")
                return
            }
            
            // Если профиль уже есть, берем его, если нет - создаем новый
            self.manager = managers?.first ?? NETunnelProviderManager()
            
            // Подписываемся на изменения статуса
            NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: self.manager?.connection, queue: .main) { _ in
                self.status = self.manager?.connection.status ?? .invalid
            }
        }
    }
    
    // Настраиваем и сохраняем профиль (появится в Настройки -> VPN на iPhone)
    func setupAndSaveVPN() {
        guard let manager = manager else { return }
        
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = "com.example.SecureVPN.TunnelProvider" // ID нашего расширения
        protocolConfiguration.serverAddress = "192.168.1.100" // IP вашего сервера
        
        // Тут можно передать секретные ключи или токены на сервер
        protocolConfiguration.providerConfiguration = [
            "port": 443,
            "protocol": "custom"
        ]
        
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "SecureVPN"
        manager.isEnabled = true
        
        manager.saveToPreferences { error in
            if let error = error {
                print("Ошибка сохранения конфигурации VPN: \(error.localizedDescription)")
            } else {
                print("VPN профиль успешно сохранен в настройки iOS!")
            }
        }
    }
    
    // Команда старта
    func connect() {
        // Перед стартом нужно убедиться, что профиль сохранен
        setupAndSaveVPN()
        
        do {
            try manager?.connection.startVPNTunnel()
        } catch {
            print("Ошибка запуска туннеля: \(error.localizedDescription)")
        }
    }
    
    // Команда остановки
    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }
}
