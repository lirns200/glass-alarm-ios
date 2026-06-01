import SwiftUI
import UIKit

@main
struct HappApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
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
