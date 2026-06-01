import SwiftUI

struct AlarmEditorView: View {
    @State private var url: String = ""
    @ObservedObject var store = AlarmStore.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Import from Clipboard
                Button {
                    importFromClipboard()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // List of Configs
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(store.configs) { config in
                            HStack {
                                Text(config.flag)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(config.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text(config.type)
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .padding()
                            .background(Color(white: 0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Subscriptions")
    }
    
    private func importFromClipboard() {
        #if os(iOS)
        if let string = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if string.starts(with: "http") {
                // Subscription URL
                fetchSubscription(url: string)
            } else {
                // Direct link or Base64 content
                let configs = SubscriptionManager.shared.decodeSubscription(string)
                if configs.isEmpty, let single = SubscriptionManager.shared.parseSingle(link: string) {
                    store.add(config: single)
                } else {
                    for config in configs {
                        store.add(config: config)
                    }
                }
            }
        }
        #else
        // Mock for testing
        let mockSub = "https://yuku-vpn.shop/sub/TWFrc3V0MiwxNzgwMTcwNTQ4NQIxSdY2-d"
        fetchSubscription(url: mockSub)
        #endif
    }
    
    private func fetchSubscription(url: String) {
        guard let fetchURL = URL(string: url) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: fetchURL)
                if let content = String(data: data, encoding: .utf8) {
                    let configs = SubscriptionManager.shared.decodeSubscription(content)
                    await MainActor.run {
                        for config in configs {
                            store.add(config: config)
                        }
                    }
                }
            } catch {
                print("Fetch error: \(error)")
            }
        }
    }
}
