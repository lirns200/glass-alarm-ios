import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage(AppSettingsKeys.selectedTheme) private var selectedTheme = AppTheme.dark.rawValue
    @AppStorage(AppSettingsKeys.defaultRingtone) private var defaultRingtone = AlarmRingtone.crystal.rawValue
    @AppStorage(AppSettingsKeys.defaultVibration) private var defaultVibration = true
    @State private var statusMessage: String?
    @State private var isSchedulingTest = false
    @State private var showingGame = false
    @State private var tapCount = 0
    @State private var lastTapTime: Date = .distantPast

    var body: some View {
        ZStack {
            GlassBackground(theme: currentTheme)

            ScrollView {
                VStack(spacing: 16) {
                    themeCard
                    defaultAlarmCard
                    testCard
                    aboutCard
                    
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassCard()
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            alarmStore.stopRingtonePreview()
        }
        .fullScreenCover(isPresented: $showingGame) {
            SecretGameView()
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .dark
    }

    private var selectedRingtone: AlarmRingtone {
        AlarmRingtone(rawValue: defaultRingtone) ?? .crystal
    }

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Тема")
                .font(.headline)

            ForEach(AppTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedTheme = theme.rawValue
                    }
                } label: {
                    HStack {
                        Label(theme.title, systemImage: theme.icon)
                        Spacer()
                        if theme.rawValue == selectedTheme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(theme.rawValue == selectedTheme ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }

    private var defaultAlarmCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("По умолчанию")
                .font(.headline)

            HStack {
                Text("Рингтон")
                Spacer()
                Picker("Рингтон", selection: $defaultRingtone) {
                    ForEach(AlarmRingtone.allCases) { ringtone in
                        Text(ringtone.title).tag(ringtone.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white.opacity(0.7))
                .onChange(of: defaultRingtone) { _, newValue in
                    let ringtone = AlarmRingtone(rawValue: newValue) ?? .crystal
                    alarmStore.previewRingtone(ringtone)
                }
            }
            .padding(.vertical, 4)

            Toggle(isOn: $defaultVibration) {
                Text("Вибрация")
            }
            .tint(Color.accentColor)
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Проверка")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    alarmStore.previewRingtone(selectedRingtone)
                } label: {
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("Звук")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    alarmStore.previewVibration()
                } label: {
                    VStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.title2)
                        Text("Вибро")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    alarmStore.stopRingtonePreview()
                } label: {
                    VStack {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text("Стоп")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { @MainActor in
                    isSchedulingTest = true
                    let ok = await alarmStore.scheduleTestNotification(after: 5)
                    isSchedulingTest = false
                    statusMessage = ok
                        ? "Тестовое уведомление через 5 сек. Сверните приложение!"
                        : "Разрешите уведомления в настройках iOS!"
                }
            } label: {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text(isSchedulingTest ? "Планирую..." : "Тестовый пуш через 5 сек")
                    Spacer()
                    if isSchedulingTest {
                        ProgressView().tint(.white)
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isSchedulingTest)
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)
                .onTapGesture {
                    handleSecretTap()
                }

            Text("Glass Alarm")
                .font(.title3.bold())

            Text("Версия 1.0.0 (Unique Build)")
                .font(.caption)
                .opacity(0.6)

            Text("Премиальный будильник с эффектом матового стекла и уникальным звуком 'Кристалл'.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(0.8)

            Divider().background(Color.white.opacity(0.2))

            Text("Разработано с любовью")
                .font(.system(size: 10, weight: .light))
                .opacity(0.4)
        }
        .foregroundStyle(.white)
        .padding(20)
        .glassCard()
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
            HapticsService.playAlarmPreview()
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
