import SwiftUI

@main
struct HappApp: App {
    private static let buildUniqueId = "af923c8273bde91029348acf823de21c"
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Dashboard", systemImage: "speedometer")
                    }
                
                NavigationView {
                    SubscriptionView()
                }
                .tabItem {
                    Label("Servers", systemImage: "list.bullet")
                }
                
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .accentColor(.blue)
            .onAppear {
                // Set TabBar background to black
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = .black
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}
