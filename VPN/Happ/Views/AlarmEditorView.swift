import SwiftUI

struct AlarmEditorView: View {
    @State private var url: String = ""
    @ObservedObject var store = AlarmStore.shared
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Import from Clipboard
                Button {
                    importFromClipboard()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 10)
                        } else {
                            Image(systemName: "doc.on.clipboard")
                        }
                        Text(isLoading ? "Fetching..." : "Paste from Clipboard")
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
                .disabled(isLoading)
                
                if !store.configs.isEmpty {
                    Button {
                        store.configs.removeAll()
                    } label: {
                        Text("Clear All")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
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
        
        var request = URLRequest(url: fetchURL)
        request.setValue("v2rayNG/1.8.5", forHTTPHeaderField: "User-Agent")
        
        isLoading = true
        
        Task {
            defer { 
                Task { @MainActor in isLoading = false }
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Debug response if needed
                if let httpResponse = response as? HTTPURLResponse {
                    print("Status code: \(httpResponse.statusCode)")
                }
                
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
