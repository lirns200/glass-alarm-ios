import SwiftUI

struct SubscriptionView: View {
    @State private var url: String = "https://yuku-vpn.shop/sub/TWFrc3V0MiwxNzgwMTcwNTQ4NQIxSdY2-d"
    @ObservedObject var store = AlarmStore.shared
    @State private var isUpdating: Bool = false
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Update button
                Button {
                    updateSubscriptions()
                } label: {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 10)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isUpdating ? "Updating..." : "Update Subscriptions")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .disabled(isUpdating)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Manual Input
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("Enter link or URL", text: $url)
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                            .foregroundStyle(.white)
                            .autocapitalization(.none)
                        
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
                    .background(Color(white: 0.15))
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                
                if !store.configs.isEmpty {
                    Button {
                        store.removeAll()
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
                            Button {
                                VPNManager.shared.selectedConfig = config
                            } label: {
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
                                    if VPNManager.shared.selectedConfig?.id == config.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                    if let ping = config.ping {
                                        Text("\(ping)ms")
                                            .font(.caption)
                                            .foregroundStyle(ping < 100 ? .green : .orange)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .background(Color(white: 0.05))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .blur(radius: isUpdating ? 3 : 0)
            
            if isUpdating {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 15) {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, lineWidth: 4)
                        .frame(width: 50, height: 50)
                        .rotationEffect(Angle(degrees: rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                    Text("Updating...")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            }
        }
        .navigationTitle("Subscriptions")
        .onAppear {
            if store.configs.isEmpty {
                updateSubscriptions()
            }
        }
    }
    
    private func updateSubscriptions() {
        processInput(url)
    }
    
    private func processInput(_ input: String) {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.starts(with: "http") {
            isUpdating = true
            VPNSubscriptionService.shared.fetchSubscription(url: cleaned) { result in
                DispatchQueue.main.async {
                    isUpdating = false
                    switch result {
                    case .success(let fetchedConfigs):
                        for config in fetchedConfigs {
                            store.add(config: config)
                        }
                    case .failure(let error):
                        print("Error fetching subscription: \(error)")
                    }
                }
            }
        } else {
            let fetchedConfigs = VPNSubscriptionService.shared.parseSubscriptionContent(cleaned)
            for config in fetchedConfigs {
                store.add(config: config)
            }
        }
    }
    
    private func importFromClipboard() {
        #if os(iOS)
        if let string = UIPasteboard.general.string {
            processInput(string)
        }
        #endif
    }
}
