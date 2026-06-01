import SwiftUI

struct ServerListView: View {
    @Binding var selectedServer: Server
    
    let servers = [
        Server(country: "Germany", city: "Frankfurt", flag: "🇩🇪", ping: 12, isPremium: true),
        Server(country: "USA", city: "New York", flag: "🇺🇸", ping: 85, isPremium: true),
        Server(country: "Japan", city: "Tokyo", flag: "🇯🇵", ping: 140, isPremium: true),
        Server(country: "UK", city: "London", flag: "🇬🇧", ping: 35, isPremium: false),
        Server(country: "Netherlands", city: "Amsterdam", flag: "🇳🇱", ping: 18, isPremium: false),
        Server(country: "Canada", city: "Toronto", flag: "🇨🇦", ping: 95, isPremium: true)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(servers) { server in
                            Button(action: {
                                selectedServer = server
                            }) {
                                HStack {
                                    Text(server.flag)
                                        .font(.title2)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.white.opacity(0.1)))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(server.country), \(server.city)")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        HStack {
                                            if server.isPremium {
                                                Image(systemName: "crown.fill").foregroundColor(.yellow).font(.system(size: 10))
                                            }
                                            Text("\(server.ping)ms")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(server.ping < 50 ? .green : .orange)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedServer.id == server.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.title2)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedServer.id == server.id ? Color.orange.opacity(0.2) : Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(selectedServer.id == server.id ? Color.orange : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Locations")
        }
    }
}
