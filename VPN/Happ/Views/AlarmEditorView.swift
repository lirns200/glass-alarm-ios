import SwiftUI

struct AlarmEditorView: View {
    @State private var url: String = ""
    @ObservedObject var store = AlarmStore.shared
    @State private var isLoading = false
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Top Action: Paste from Clipboard (Moved Higher)
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
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .disabled(isLoading)

                // Manual Input Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Manual Import")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 25)
                    
                    HStack {
                        TextField("Enter link or subscription URL", text: $url)
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                            .foregroundStyle(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button {
                            if !url.isEmpty {
                                processInput(url)
                                url = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                if !store.configs.isEmpty {
                    Button {
                        store.configs.removeAll()
                    } label: {
                        Text("Clear All")
                            .foregroundColor(.red.opacity(0.7))
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
            .blur(radius: isLoading ? 3 : 0)

            // Custom Loading Overlay
            if isLoading {
                Color.black.opacity(0.6).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        // Rotating semi-circle (half circle)
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(Angle(degrees: rotation))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                                    rotation = 360
                                }
                            }
                    }
                    
                    Text("Проверяем...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Subscriptions")
    }

    private func processInput(_ input: String) {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.starts(with: "http") {
            fetchSubscription(url: cleaned)
        } else {
            let configs = SubscriptionManager.shared.decodeSubscription(cleaned)
            if configs.isEmpty, let single = SubscriptionManager.shared.parseSingle(link: cleaned) {
                store.add(config: single)
            } else {
                for config in configs {
                    store.add(config: config)
                }
            }
        }
    }
    
    private func importFromClipboard() {
        #if os(iOS)
        if let string = UIPasteboard.general.string {
            processInput(string)
        }
        #else
        // Mock for testing
        let mockSub = "https://yuku-vpn.shop/sub/TWFrc3V0MiwxNzgwMTcwNTQ4NQIxSdY2-d"
        processInput(mockSub)
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
