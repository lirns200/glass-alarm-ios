import SwiftUI

struct SubscriptionView: View {
    @State private var url: String = ""
    @ObservedObject var store = AlarmStore.shared
    @State private var isUpdating: Bool = false
    @State private var showManualInput: Bool = false
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 15) {
                // 1. Paste from Clipboard (High priority)
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
                
                // 2. Add Link Manually Button
                Button {
                    withAnimation(.spring()) {
                        showManualInput.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: showManualInput ? "keyboard.chevron.compact.down" : "plus.circle")
                        Text(showManualInput ? "Hide Input" : "Add Link Manually")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                
                // 3. Conditional Manual Input Field
                if showManualInput {
                    VStack(spacing: 10) {
                        TextField("vless:// or subscription URL", text: $url)
                            .padding()
                            .background(Color(white: 0.18))
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                            .autocapitalization(.none)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        
                        Button {
                            if !url.isEmpty {
                                processInput(url)
                                url = ""
                                withAnimation { showManualInput = false }
                            }
                        } label: {
                            Text("Confirm & Add")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(10)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                HStack {
                    Text("Your Servers")
                        .font(.caption.bold())
                        .foregroundStyle(.gray)
                    Spacer()
                    if !store.configs.isEmpty {
                        Button {
                            withAnimation { store.removeAll() }
                        } label: {
                            Text("Clear All")
                                .foregroundColor(.red.opacity(0.6))
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 10)

                // 4. List of Configs with Real Animation
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.configs) { config in
                            Button {
                                withAnimation(.interactiveSpring()) {
                                    VPNManager.shared.selectedConfig = config
                                }
                            } label: {
                                HStack {
                                    Text(config.flag)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(config.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                        Text(config.type)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.blue.opacity(0.8))
                                    }
                                    Spacer()
                                    
                                    if VPNManager.shared.selectedConfig?.id == config.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .transition(.scale)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .background(Color(white: 0.07))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VPNManager.shared.selectedConfig?.id == config.id ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .blur(radius: isUpdating ? 3 : 0)
            
            // Modern Loading Overlay
            if isUpdating {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 15) {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(Angle(degrees: rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                    Text("Fetching Nodes...")
                        .foregroundStyle(.white)
                        .font(.system(.headline, design: .monospaced))
                }
            }
        }
        .navigationTitle("Subscriptions")
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
                        withAnimation(.spring()) {
                            for config in fetchedConfigs {
                                store.add(config: config)
                            }
                        }
                    case .failure(let error):
                        print("Error: \(error)")
                    }
                }
            }
        } else {
            let fetchedConfigs = VPNSubscriptionService.shared.parseSubscriptionContent(cleaned)
            withAnimation(.spring()) {
                for config in fetchedConfigs {
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
        // Mock for desktop testing
        processInput("https://yuku-vpn.shop/sub/TWFrc3V0MiwxNzgwMTcwNTQ4NQIxSdY2-d")
        #endif
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
