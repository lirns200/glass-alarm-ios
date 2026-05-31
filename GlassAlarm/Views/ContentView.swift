import SwiftUI
import AVFoundation

// Sound Manager
class SoundManager {
    static let instance = SoundManager()
    private var player: AVAudioPlayer?
    
    func playSound(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case chinese = "zh"
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .chinese: return "中文"
        }
    }
}

struct GameShape: Identifiable {
    let id = UUID()
    let blocks: [CGPoint]
    let color: Color
    
    static let templates: [GameShape] = [
        GameShape(blocks: [CGPoint(x: 0, y: 0)], color: .blue),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)], color: .cyan),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1)], color: .cyan),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)], color: .purple),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 2)], color: .purple),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1)], color: .orange),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0)], color: .red),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)], color: .yellow),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 1, y: 1)], color: .pink),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 2)], color: .blue),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), 
                           CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 1),
                           CGPoint(x: 0, y: 2), CGPoint(x: 1, y: 2), CGPoint(x: 2, y: 2)], color: .indigo),
    ]
    
    static func random() -> GameShape {
        templates.randomElement()!
    }
}

struct ScorePopup: Identifiable {
    let id = UUID()
    let score: Int
    let position: CGPoint
}

@MainActor
class GameViewModel: ObservableObject {
    @Published var grid: [[Color?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @Published var currentShapes: [GameShape?] = []
    @Published var score: Int = 0
    @Published var highscore: Int = UserDefaults.standard.integer(forKey: "highscore")
    @Published var isGameOver: Bool = false
    @Published var combo: Int = 0
    @Published var previewInfo: (row: Int, col: Int, shape: GameShape)?
    @Published var popups: [ScorePopup] = []
    
    // Settings
    @Published var isSoundEnabled: Bool = true
    @Published var isVibrationEnabled: Bool = true
    @Published var isDarkMode: Bool = true
    @Published var language: Language = .english
    
    init() {
        startNewRound()
    }
    
    func startNewRound() {
        currentShapes = [GameShape.random(), GameShape.random(), GameShape.random()]
    }
    
    func setPreview(row: Int, col: Int, shape: GameShape?) {
        if let shape = shape {
            previewInfo = (row, col, shape)
        } else {
            previewInfo = nil
        }
    }
    
    func canPlace(shape: GameShape, at row: Int, col: Int) -> Bool {
        for block in shape.blocks {
            let r = row + Int(block.y)
            let c = col + Int(block.x)
            if r < 0 || r >= 8 || c < 0 || c >= 8 || grid[r][c] != nil {
                return false
            }
        }
        return true
    }
    
    func place(shape: GameShape, at row: Int, col: Int) {
        guard canPlace(shape: shape, at: row, col: col) else { return }
        
        if isSoundEnabled { SoundManager.instance.playSound(name: "focus") }
        if isVibrationEnabled { triggerPlacementFeedback(style: .light) }
        
        for block in shape.blocks {
            let r = row + Int(block.y)
            let c = col + Int(block.x)
            grid[r][c] = shape.color
        }
        if let index = currentShapes.firstIndex(where: { $0?.id == shape.id }) {
            currentShapes[index] = nil
        }
        
        Task {
            await clearLinesSequential(at: row, col: col)
            if currentShapes.allSatisfy({ $0 == nil }) { startNewRound() }
            checkGameOver()
        }
    }
    
    private func triggerPlacementFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }
    
    private func clearLinesSequential(at lastRow: Int, col lastCol: Int) async {
        var rowsToClear: [Int] = []
        var colsToClear: [Int] = []
        for r in 0..<8 { if grid[r].allSatisfy({ $0 != nil }) { rowsToClear.append(r) } }
        for c in 0..<8 {
            var full = true
            for r in 0..<8 { if grid[r][c] == nil { full = false; break } }
            if full { colsToClear.append(c) }
        }
        
        let linesCleared = rowsToClear.count + colsToClear.count
        if linesCleared > 0 {
            combo += 1
            let points = (linesCleared * 100 + (combo - 1) * 50) * linesCleared
            
            let popup = ScorePopup(score: points, position: CGPoint(x: CGFloat(lastCol) * 40, y: CGFloat(lastRow) * 40))
            popups.append(popup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.popups.removeAll { $0.id == popup.id } }

            withAnimation(.spring()) {
                score += points
                if score > highscore {
                    highscore = score
                    UserDefaults.standard.set(highscore, forKey: "highscore")
                }
            }

            var coords: [ (Int, Int) ] = []
            for r in rowsToClear { for c in 0..<8 { coords.append((r, c)) } }
            for c in colsToClear { for r in 0..<8 { if !rowsToClear.contains(r) { coords.append((r, c)) } } }
            coords.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
            
            for coord in coords {
                try? await Task.sleep(nanoseconds: 25_000_000)
                grid[coord.0][coord.1] = nil
                if isVibrationEnabled { triggerPlacementFeedback(style: .soft) }
                if isSoundEnabled { SoundManager.instance.playSound(name: "crystal") }
            }
        } else { combo = 0 }
    }
    
    private func checkGameOver() {
        for shape in currentShapes.compactMap({ $0 }) {
            for r in 0..<8 {
                for c in 0..<8 {
                    if canPlace(shape: shape, at: r, col: c) { return }
                }
            }
        }
        withAnimation { isGameOver = true }
    }
    
    func reset() {
        grid = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        score = 0; combo = 0; isGameOver = false; startNewRound()
    }
    
    var comboColor: Color {
        if combo <= 1 { return .gray }
        if combo <= 5 { return .yellow }
        return .red
    }
    
    func t(_ key: String) -> String {
        let localized: [Language: [String: String]] = [
            .english: [
                "score": "SCORE", "record": "BEST", "combo": "COMBO", "gameover": "GAME OVER",
                "tryagain": "TRY AGAIN", "settings": "Settings", "gameplay": "GAMEPLAY",
                "sound": "Sound Effects", "vibration": "Vibration", "appearance": "APPEARANCE",
                "darkmode": "Dark Mode", "language": "Language", "about": "ABOUT", "done": "Done"
            ],
            .russian: [
                "score": "СЧЕТ", "record": "РЕКОРД", "combo": "КОМБО", "gameover": "ИГРА ОКОНЧЕНА",
                "tryagain": "ПОПРОБОВАТЬ СНОВА", "settings": "Настройки", "gameplay": "ГЕЙМПЛЕЙ",
                "sound": "Звуковые эффекты", "vibration": "Вибрация", "appearance": "ОФОРМЛЕНИЕ",
                "darkmode": "Темная тема", "language": "Язык", "about": "О ПРИЛОЖЕНИИ", "done": "Готово"
            ],
            .chinese: [
                "score": "分数", "record": "最高分", "combo": "连击", "gameover": "游戏结束",
                "tryagain": "再试一次", "settings": "设置", "gameplay": "玩法",
                "sound": "音效", "vibration": "震动", "appearance": "外观",
                "darkmode": "深色模式", "language": "语言", "about": "关于", "done": "完成"
            ]
        ]
        return localized[language]?[key] ?? key
    }
}

struct SplashScreen: View {
    @State private var opacity = 0.0
    @State private var scale = 0.8
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("developed by")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.gray)
                Text("YUKU")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(10)
            }
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) { opacity = 1.0; scale = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.5)) { opacity = 0.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onFinished() }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var gridRect: CGRect = .zero
    @State private var showingSettings = false
    @State private var isSplashActive = true
    @State private var flamePhase = 0.0
    
    var body: some View {
        ZStack {
            if isSplashActive { SplashScreen { isSplashActive = false } }
            else { gameContent.preferredColorScheme(vm.isDarkMode ? .dark : .light) }
        }
    }
    
    var gameContent: some View {
        ZStack {
            (vm.isDarkMode ? Color(red: 0.02, green: 0.04, blue: 0.08) : Color(red: 0.95, green: 0.96, blue: 0.98)).ignoresSafeArea()
            VStack(spacing: 15) {
                HStack {
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(vm.isDarkMode ? .white : .black)
                            .padding(12).background(vm.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), in: Circle())
                    }
                }.padding(.horizontal, 20).padding(.top, 10)
                
                VStack(spacing: 2) {
                    Text("\(vm.t("record")): \(vm.highscore)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.orange.opacity(0.8))
                    Text(vm.t("score")).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.gray)
                    Text("\(vm.score)").font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(vm.score >= vm.highscore && vm.score > 0 ? .orange : (vm.isDarkMode ? .white : .black))
                        .shadow(color: vm.score >= vm.highscore && vm.score > 0 ? .red.opacity(0.3) : .clear, radius: 8)
                        .scaleEffect(vm.score >= vm.highscore && vm.score > 0 ? 1.05 + sin(flamePhase) * 0.03 : 1.0)
                }.onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { flamePhase = .pi * 2 } }
                
                HStack {
                    ZStack {
                        if vm.combo > 1 {
                            VStack(spacing: -2) {
                                Text(vm.t("combo")).font(.system(size: 8, weight: .bold, design: .rounded))
                                Text("x\(vm.combo)").font(.system(size: 18, weight: .black, design: .rounded))
                            }.foregroundStyle(vm.comboColor).padding(6).background(vm.comboColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10)).transition(.scale.combined(with: .opacity))
                        }
                    }.frame(width: 60)
                    Spacer().frame(width: 60)
                }
                
                ZStack {
                    GridView(grid: vm.grid, preview: vm.previewInfo, canPlace: vm.canPlace, isDarkMode: vm.isDarkMode)
                        .background(GeometryReader { geo in Color.clear.onAppear { gridRect = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in gridRect = newFrame } })
                    ForEach(vm.popups) { popup in
                        Text("+\(popup.score)").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.orange).shadow(radius: 2)
                            .position(x: popup.position.x + 20, y: popup.position.y + 20).transition(.asymmetric(insertion: .scale, removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }.padding(16).background(vm.isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 16)
                
                HStack(spacing: 15) {
                    ForEach(vm.currentShapes.indices, id: \.self) { i in
                        ZStack {
                            if let shape = vm.currentShapes[i] {
                                DraggableShapeView(shape: shape, gridRect: gridRect, onHover: { r, c, s in vm.setPreview(row: r, col: c, shape: s) }) { row, col in vm.place(shape: shape, at: row, col: col) }
                            }
                        }.frame(maxWidth: .infinity).frame(height: 120)
                    }
                }.padding(.horizontal, 20)
                Spacer()
            }
        }.sheet(isPresented: $showingSettings) { GameSettingsMenuView(vm: vm) }
        .overlay { if vm.isGameOver { gameOverOverlay } }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(spacing: 40) {
                ZStack {
                    ForEach(0..<10) { i in Circle().fill(Color.orange.opacity(0.3)).frame(width: 200, height: 200).blur(radius: 50).offset(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100)) }
                }
                VStack(spacing: 10) {
                    Text(vm.t("gameover")).font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
                    Text("\(vm.score)").font(.system(size: 80, weight: .black, design: .rounded)).foregroundStyle(.orange)
                }
                Button { withAnimation { vm.reset() } } label: {
                    Text(vm.t("tryagain")).font(.title3.bold()).foregroundStyle(.white).padding(.horizontal, 50).padding(.vertical, 20).background(Color.blue, in: Capsule()).shadow(color: .blue.opacity(0.4), radius: 15)
                }
            }
        }.transition(.opacity.combined(with: .scale))
    }
}

struct GameSettingsMenuView: View {
    @ObservedObject var vm: GameViewModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section(vm.t("gameplay")) {
                    Toggle(vm.t("sound"), isOn: $vm.isSoundEnabled)
                    Toggle(vm.t("vibration"), isOn: $vm.isVibrationEnabled)
                }
                Section(vm.t("appearance")) {
                    Toggle(vm.t("darkmode"), isOn: $vm.isDarkMode)
                    Picker(vm.t("language"), selection: $vm.language) { ForEach(Language.allCases) { lang in Text(lang.name).tag(lang) } }
                }
                Section(vm.t("about")) {
                    Text("Version 1.5.0").foregroundStyle(.gray)
                    Text("Block Blast - developed by YUKU team.").font(.caption).foregroundStyle(.gray)
                }
            }.navigationTitle(vm.t("settings")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(vm.t("done")) { dismiss() } } }
        }
    }
}

struct GridView: View {
    let grid: [[Color?]]
    let preview: (row: Int, col: Int, shape: GameShape)?
    let canPlace: (GameShape, Int, Int) -> Bool
    let isDarkMode: Bool
    var body: some View {
        AspectRatioContainer(aspectRatio: 1) {
            ZStack {
                VStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 4) {
                            ForEach(0..<8, id: \.self) { c in
                                RoundedRectangle(cornerRadius: 6).fill(grid[r][c] ?? (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 1))
                                    .scaleEffect(grid[r][c] != nil ? 1.0 : 0.95)
                            }
                        }
                    }
                }
                if let p = preview {
                    let isPossible = canPlace(p.shape, p.row, p.col)
                    VStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { r in
                            HStack(spacing: 4) {
                                ForEach(0..<8, id: \.self) { c in
                                    let isPreviewBlock = p.shape.blocks.contains { block in Int(block.y) + p.row == r && Int(block.x) + p.col == c }
                                    if isPreviewBlock { RoundedRectangle(cornerRadius: 6).fill(isPossible ? p.shape.color.opacity(0.5) : Color.red.opacity(0.3)) }
                                    else { Color.clear }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AspectRatioContainer<Content: View>: View {
    let aspectRatio: CGFloat
    let content: () -> Content
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            content().frame(width: side, height: side).position(x: geo.size.width / 2, y: geo.size.height / 2)
        }.aspectRatio(aspectRatio, contentMode: .fit)
    }
}

struct DraggableShapeView: View {
    let shape: GameShape
    let gridRect: CGRect
    let onHover: (Int, Int, GameShape?) -> Void
    let onDrop: (Int, Int) -> Void
    @State private var offset = CGSize.zero
    @State private var isDragging = false
    var body: some View {
        ShapePreview(shape: shape, scale: isDragging ? 0.85 : 0.6)
            .offset(offset).zIndex(isDragging ? 10 : 1)
            .gesture(DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    withAnimation(.easeOut(duration: 0.1)) { isDragging = true }
                    offset = CGSize(width: value.translation.width, height: value.translation.height - 80)
                    let hoverPoint = CGPoint(x: value.location.x, y: value.location.y - 80)
                    if gridRect.contains(hoverPoint) {
                        let cellSize = gridRect.width / 8
                        let localX = hoverPoint.x - gridRect.minX
                        let localY = hoverPoint.y - gridRect.minY
                        let col = Int(round((localX - cellSize/2) / cellSize))
                        let row = Int(round((localY - cellSize/2) / cellSize))
                        onHover(row, col, shape)
                    } else { onHover(0, 0, nil) }
                }
                .onEnded { value in
                    let dropPoint = CGPoint(x: value.location.x, y: value.location.y - 80)
                    if gridRect.contains(dropPoint) {
                        let cellSize = gridRect.width / 8
                        let localX = dropPoint.x - gridRect.minX
                        let localY = dropPoint.y - gridRect.minY
                        let col = Int(round((localX - cellSize/2) / cellSize))
                        let row = Int(round((localY - cellSize/2) / cellSize))
                        onDrop(row, col)
                    }
                    onHover(0, 0, nil)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = .zero; isDragging = false }
                })
    }
}

struct ShapePreview: View {
    let shape: GameShape
    let scale: CGFloat
    var body: some View {
        ZStack {
            ForEach(shape.blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: 4).fill(shape.color)
                    .frame(width: 34 * scale, height: 34 * scale)
                    .offset(x: block.x * 38 * scale, y: block.y * 38 * scale)
            }
        }
    }
}
