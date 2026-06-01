import SwiftUI

struct AnimatedClockCard: View {
    let nextAlarm: Alarm?
    @State private var pulse = false
    @State private var rotation = 0.0
    
    @State private var tapCount = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var showingGame = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.08), lineWidth: 22)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0.05, to: 0.82)
                    .stroke(
                        AngularGradient(colors: [.cyan, .indigo, .pink, .cyan], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .cyan.opacity(0.28), radius: 18)

                Circle()
                    .stroke(.white.opacity(0.26), lineWidth: 1)
                    .frame(width: pulse ? 160 : 138, height: pulse ? 160 : 138)
                    .opacity(pulse ? 0.2 : 0.72)

                VStack(spacing: 4) {
                    Text(nextAlarm?.timeText ?? "--:--")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(nextAlarm == nil ? "Нет активных" : "Следующий")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                }
                .onTapGesture {
                    handleSecretTap()
                }
            }
            .padding(.top, 8)

            VStack(spacing: 4) {
                Text(nextAlarm?.repeatText ?? "Нажмите +, чтобы создать")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                
                if let nextAlarm {
                    Text(nextAlarm.timeUntilText)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassCard()
        .fullScreenCover(isPresented: $showingGame) {
            SecretGameView()
        }
        .onAppear {
            withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func handleSecretTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.5 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now

        if tapCount >= 5 {
            tapCount = 0
            showingGame = true
        }
    }
}

struct SecretGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerX: CGFloat = 150
    @State private var score = 0
    @State private var objects: [GameObject] = []
    @State private var isGameOver = false
    
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Stars/Background
                ForEach(0..<20) { i in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 2)
                        .position(x: CGFloat(i * 20), y: CGFloat((i * 45) % Int(geo.size.height)))
                }

                // Player (Glass Shield)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                    .frame(width: 60, height: 20)
                    .position(x: playerX, y: geo.size.height - 100)
                    .blur(radius: 1)

                // Falling Objects (Crystals)
                ForEach(objects) { obj in
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(Color.accentColor)
                        .position(x: obj.x, y: obj.y)
                }

                // UI
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.title2.bold())
                        Spacer()
                        Button("Exit") { dismiss() }
                            .padding(8)
                            .background(Color.red.opacity(0.5), in: Capsule())
                    }
                    .padding()
                    Spacer()
                }
                .foregroundStyle(.white)

                if isGameOver {
                    VStack {
                        Text("GAME OVER")
                            .font(.largeTitle.bold())
                        Text("Score: \(score)")
                        Button("Try Again") {
                            score = 0
                            objects = []
                            isGameOver = false
                        }
                        .padding()
                        .background(Color.accentColor, in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(40)
                    .glassCard()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isGameOver {
                            playerX = value.location.x
                        }
                    }
            )
            .onReceive(timer) { _ in
                if !isGameOver {
                    updateGame(in: geo.size)
                }
            }
        }
    }

    private func updateGame(in size: CGSize) {
        // Spawn
        if Int.random(in: 0...50) == 0 {
            objects.append(GameObject(x: CGFloat.random(in: 20...size.width-20), y: -20))
        }

        // Move
        for i in objects.indices {
            objects[i].y += 4
        }

        // Collision & Remove
        let playerRect = CGRect(x: playerX - 30, y: size.height - 110, width: 60, height: 20)
        
        objects.removeAll { obj in
            let objRect = CGRect(x: obj.x - 10, y: obj.y - 10, width: 20, height: 20)
            if playerRect.intersects(objRect) {
                score += 1
                return true
            }
            if obj.y > size.height {
                isGameOver = true
                return true
            }
            return false
        }
    }
}

struct GameObject: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
}
