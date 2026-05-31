import SwiftUI
import AVFoundation

// Sound Manager
class SoundManager {
    static let instance = SoundManager()
    private var player: AVAudioPlayer?
    
    func playSound(name: String) {
        // Fallback to haptics if sound file is missing or generic
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { 
            print("Sound file \(name).wav not found")
            return 
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case english = "en", russian = "ru", chinese = "zh"
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
    
    static let allTemplates: [GameShape] = [
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
    
    static func random(for size: Int) -> GameShape {
        // Filter shapes that actually fit in the grid
        let fits = allTemplates.filter { shape in
            let maxX = shape.blocks.map { Int($0.x) }.max() ?? 0
            let maxY = shape.blocks.map { Int($0.y) }.max() ?? 0
            return maxX < size && maxY < size
        }
        return fits.randomElement() ?? allTemplates[0]
    }
}

struct ScorePopup: Identifiable {
    let id = UUID()
    let score: Int
    let position: CGPoint
}

@MainActor
class GameViewModel: ObservableObject {
    @Published var gridSize: Int = 8
    @Published var grid: [[Color?]] = []
    @Published var currentShapes: [GameShape?] = []
    @Published var score: Int = 0
    @Published var highscore: Int = UserDefaults.standard.integer(forKey: "highscore")
    @Published var isGameOver: Bool = false
    @Published var combo: Int = 0
    @Published var previewInfo: (row: Int, col: Int, shape: GameShape)?
    @Published var popups: [ScorePopup] = []
    
    @Published var isSoundEnabled: Bool = true
    @Published var isVibrationEnabled: Bool = true
    @Published var isDarkMode: Bool = true
    @Published var language: Language = .english
    
    init() {
        setupGrid(size: 8)
    }
    
    func setupGrid(size: Int) {
        gridSize = size
        grid = Array(repeating: Array(repeating: nil, count: size), count: size)
        score = 0
        combo = 0
        isGameOver = false
        startNewRound()
    }
    
    func startNewRound() {
        var shapes: [GameShape?] = []
        for _ in 0..<3 {
            var shape = GameShape.random(for: gridSize)
            // Try to find a shape that can actually be placed at least somewhere
            var attempts = 0
            while attempts < 10 && !canPlaceSomewhere(shape) {
                shape = GameShape.random(for: gridSize)
                attempts += 1
            }
            shapes.append(shape)
        }
        currentShapes = shapes
    }
    
    private func canPlaceSomewhere(_ shape: GameShape) -> Bool {
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if canPlace(shape: shape, at: r, col: c) {
                    return true
                }
            }
        }
        return false
    }
    
    func setPreview(row: Int, col: Int, shape: GameShape?) {
        if let shape = shape { previewInfo = (row, col, shape) }
        else { previewInfo = nil }
    }
    
    func canPlace(shape: GameShape, at row: Int, col: Int) -> Bool {
        for block in shape.blocks {
            let r = row + Int(block.y)
            let c = col + Int(block.x)
            if r < 0 || r >= gridSize || c < 0 || c >= gridSize || grid[r][c] != nil { return false }
        }
        return true
    }
    
    func place(shape: GameShape, at row: Int, col: Int, in rect: CGRect) {
        guard canPlace(shape: shape, at: row, col: col) else { return }
        if isSoundEnabled { SoundManager.instance.playSound(name: "pup") }
        if isVibrationEnabled { triggerPlacementFeedback(style: .light) }
        for block in shape.blocks {
            let r = row + Int(block.y), c = col + Int(block.x)
            grid[r][c] = shape.color
        }
        if let index = currentShapes.firstIndex(where: { $0?.id == shape.id }) { currentShapes[index] = nil }
        Task {
            await clearLinesSequential(at: row, col: col, in: rect)
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
    
    private func clearLinesSequential(at lastRow: Int, col lastCol: Int, in rect: CGRect) async {
        var rowsToClear: [Int] = [], colsToClear: [Int] = []
        for r in 0..<gridSize { if grid[r].allSatisfy({ $0 != nil }) { rowsToClear.append(r) } }
        for c in 0..<gridSize {
            var full = true
            for r in 0..<gridSize { if grid[r][c] == nil { full = false; break } }
            if full { colsToClear.append(c) }
        }
        let linesCleared = rowsToClear.count + colsToClear.count
        if linesCleared > 0 {
            combo += 1
            let points = (linesCleared * 100 + (combo - 1) * 50) * linesCleared
            
            // Calculate center position for the popup relative to the grid view
            let cellSize = rect.width / CGFloat(gridSize)
            let popupX = CGFloat(lastCol) * cellSize + cellSize / 2
            let popupY = CGFloat(lastRow) * cellSize + cellSize / 2
            
            let popup = ScorePopup(score: points, position: CGPoint(x: popupX, y: popupY))
            popups.append(popup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.popups.removeAll { $0.id == popup.id } }
            withAnimation(.spring()) {
                score += points
                if score > highscore { highscore = score; UserDefaults.standard.set(highscore, forKey: "highscore") }
            }
            var coords: [(Int, Int)] = []
            for r in rowsToClear { for c in 0..<gridSize { coords.append((r, c)) } }
            for c in colsToClear { for r in 0..<gridSize { if !rowsToClear.contains(r) { coords.append((r, c)) } } }
            coords.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
            for coord in coords {
                try? await Task.sleep(nanoseconds: 20_000_000)
                grid[coord.0][coord.1] = nil
                if isVibrationEnabled { triggerPlacementFeedback(style: .soft) }
                if isSoundEnabled { SoundManager.instance.playSound(name: "pup") }
            }
        } else { combo = 0 }
    }
    
    private func checkGameOver() {
        for shape in currentShapes.compactMap({ $0 }) {
            for r in 0..<gridSize { for c in 0..<gridSize { if canPlace(shape: shape, at: r, col: c) { return } } }
        }
        withAnimation { isGameOver = true }
    }
    
    func reset() { setupGrid(size: gridSize) }
    
    var comboColor: Color {
        if combo <= 1 { return .gray }
        if combo <= 5 { return .yellow }
        return .red
    }
    
    func t(_ key: String) -> String {
        let localized: [Language: [String: String]] = [
            .english: ["score": "SCORE", "record": "BEST", "combo": "COMBO", "gameover": "GAME OVER", "tryagain": "TRY AGAIN", "settings": "Settings", "gameplay": "GAMEPLAY", "sound": "Sound Effects", "vibration": "Vibration", "appearance": "APPEARANCE", "darkmode": "Dark Mode", "language": "Language", "about": "ABOUT", "done": "Done", "modes": "Modes"],
            .russian: ["score": "СЧЕТ", "record": "РЕКОРД", "combo": "КОМБО", "gameover": "ИГРА ОКОНЧЕНА", "tryagain": "ПОПРОБОВАТЬ СНОВА", "settings": "Настройки", "gameplay": "ГЕЙМПЛЕЙ", "sound": "Звуки", "vibration": "Вибрация", "appearance": "ОФОРМЛЕНИЕ", "darkmode": "Темная тема", "language": "Язык", "about": "О ИГРЕ", "done": "Готово", "modes": "Режимы"],
            .chinese: ["score": "分数", "record": "最高分", "combo": "连击", "gameover": "游戏结束", "tryagain": "再试一次", "settings": "设置", "gameplay": "玩法", "sound": "音效", "vibration": "震动", "appearance": "外观", "darkmode": "深色模式", "language": "语言", "about": "关于", "done": "完成", "modes": "模式"]
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
                Text("developed by").font(.system(.subheadline, design: .monospaced)).foregroundStyle(.gray)
                Text("YUKU").font(.system(size: 60, weight: .black, design: .rounded)).foregroundStyle(.white).tracking(10)
            }.opacity(opacity).scaleEffect(scale)
        }.onAppear {
            withAnimation(.easeIn(duration: 1.0)) { opacity = 1.0; scale = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) { opacity = 0.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onFinished() }
            }
        }
    }
}

struct ModeSelectorView: View {
    @ObservedObject var vm: GameViewModel
    @Environment(\.dismiss) var dismiss
    let sizes = [3, 4, 5, 6, 8, 10, 12, 16]
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(sizes, id: \.self) { size in
                        Button { vm.setupGrid(size: size); dismiss() } label: {
                            VStack {
                                gridIcon(size: size).frame(width: 80, height: 80).padding()
                                    .background(vm.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                                Text("\(size)x\(size)").font(.headline).foregroundStyle(vm.isDarkMode ? .white : .black)
                            }
                        }
                    }
                }.padding()
            }.navigationTitle(vm.t("modes")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(vm.t("done")) { dismiss() } } }
        }
    }
    func gridIcon(size: Int) -> some View {
        let displaySize = min(size, 6)
        return VStack(spacing: 2) {
            ForEach(0..<displaySize, id: \.self) { _ in
                HStack(spacing: 2) {
                    ForEach(0..<displaySize, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(.blue.opacity(0.5)).frame(width: CGFloat(40/displaySize), height: CGFloat(40/displaySize))
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var gridRect: CGRect = .zero
    @State private var showingSettings = false
    @State private var showingModes = false
    @State private var isSplashActive = true
    @State private var flamePhase = 0.0
    
    var body: some View {
        ZStack {
            if isSplashActive {
                SplashScreen { isSplashActive = false }
            } else {
                gameContent
                    .preferredColorScheme(vm.isDarkMode ? .dark : .light)
            }
        }
    }
    
    var gameContent: some View {
        ZStack {
            (vm.isDarkMode ? Color(red: 0.02, green: 0.04, blue: 0.08) : Color(red: 0.95, green: 0.96, blue: 0.98))
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                // Header
                HStack {
                    Button {
                        showingModes = true
                    } label: {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.title3)
                            .foregroundStyle(vm.isDarkMode ? .white : .black)
                            .padding(12)
                            .background(vm.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), in: Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(vm.isDarkMode ? .white : .black)
                            .padding(12)
                            .background(vm.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Centered Score & Record
                VStack(spacing: 4) {
                    Text("\(vm.t("record")): \(vm.highscore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    HStack(spacing: 15) {
                        // Combo Indicator (now clearly positioned)
                        ZStack {
                            if vm.combo > 1 {
                                VStack(spacing: -2) {
                                    Text(vm.t("combo"))
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                    Text("x\(vm.combo)")
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                }
                                .foregroundStyle(vm.comboColor)
                                .padding(6)
                                .background(vm.comboColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .frame(width: 60)
                        
                        // Score with "Fire" effect if beating record
                        Text("\(vm.score)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(vm.score >= vm.highscore && vm.score > 0 ? .orange : (vm.isDarkMode ? .white : .black))
                            .shadow(color: vm.score >= vm.highscore && vm.score > 0 ? .red.opacity(0.4) : .clear, radius: 8)
                            .scaleEffect(vm.score >= vm.highscore && vm.score > 0 ? 1.05 + sin(flamePhase) * 0.03 : 1.0)
                        
                        // Balance for the combo element
                        Spacer().frame(width: 60)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                        flamePhase = .pi * 2
                    }
                }
                
                // Grid
                ZStack {
                    GridView(grid: vm.grid, size: vm.gridSize, preview: vm.previewInfo, canPlace: vm.canPlace, isDarkMode: vm.isDarkMode)
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear {
                                    gridRect = geo.frame(in: .global)
                                }
                                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                    gridRect = newFrame
                                }
                            }
                        )
                    
                    // Floating scores
                    ForEach(vm.popups) { popup in
                        Text("+\(popup.score)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                            .shadow(radius: 2)
                            .position(popup.position)
                            .transition(.asymmetric(insertion: .scale, removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }
                .padding(12)
                .background(vm.isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                
                // Shapes
                HStack(spacing: 10) {
                    ForEach(vm.currentShapes.indices, id: \.self) { i in
                        ZStack {
                            if let shape = vm.currentShapes[i] {
                                DraggableShapeView(shape: shape, gridRect: gridRect, gridSize: vm.gridSize, onHover: { r, c, s in
                                    vm.setPreview(row: r, col: c, shape: s)
                                }) { row, col in
                                    vm.place(shape: shape, at: row, col: col, in: gridRect)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            GameSettingsMenuView(vm: vm)
        }
        .sheet(isPresented: $showingModes) {
            ModeSelectorView(vm: vm)
        }
        .overlay {
            if vm.isGameOver {
                gameOverOverlay
            }
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(spacing: 30) {
                Text(vm.t("gameover")).font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("\(vm.score)").font(.system(size: 70, weight: .black, design: .rounded)).foregroundStyle(.orange)
                Button { withAnimation { vm.reset() } } label: {
                    Text(vm.t("tryagain")).font(.title3.bold()).foregroundStyle(.white).padding(.horizontal, 40).padding(.vertical, 18).background(Color.blue, in: Capsule())
                }
            }
        }
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
            }.navigationTitle(vm.t("settings")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(vm.t("done")) { dismiss() } } }
        }
    }
}

struct GridView: View {
    let grid: [[Color?]], size: Int
    let preview: (row: Int, col: Int, shape: GameShape)?
    let canPlace: (GameShape, Int, Int) -> Bool
    let isDarkMode: Bool
    var body: some View {
        AspectRatioContainer(aspectRatio: 1) {
            ZStack {
                VStack(spacing: 2) {
                    ForEach(0..<size, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(0..<size, id: \.self) { c in
                                RoundedRectangle(cornerRadius: 4).fill(grid[r][c] ?? (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                                    .scaleEffect(grid[r][c] != nil ? 1.0 : 0.95)
                            }
                        }
                    }
                }
                if let p = preview {
                    let isPossible = canPlace(p.shape, p.row, p.col)
                    VStack(spacing: 2) {
                        ForEach(0..<size, id: \.self) { r in
                            HStack(spacing: 2) {
                                ForEach(0..<size, id: \.self) { c in
                                    let isPreviewBlock = p.shape.blocks.contains { block in Int(block.y) + p.row == r && Int(block.x) + p.col == c }
                                    if isPreviewBlock { RoundedRectangle(cornerRadius: 4).fill(isPossible ? p.shape.color.opacity(0.5) : Color.red.opacity(0.3)) }
                                    else { Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity) }
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
    let aspectRatio: CGFloat, content: () -> Content
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
    let gridSize: Int
    let onHover: (Int, Int, GameShape?) -> Void
    let onDrop: (Int, Int) -> Void
    @State private var offset = CGSize.zero
    @State private var isDragging = false
    
    private var dragScale: CGFloat {
        let cellSize = gridRect.width / CGFloat(gridSize)
        return cellSize / 30.0 // Adjusted for 30px base block size
    }
    
    var body: some View {
        ShapePreview(shape: shape, scale: isDragging ? dragScale : 0.5)
            .offset(offset).zIndex(isDragging ? 10 : 1)
            .gesture(DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    isDragging = true
                    // Lift the shape 120 points above the finger for better visibility
                    offset = CGSize(width: value.translation.width, height: value.translation.height - 120)
                    let hoverPoint = CGPoint(x: value.location.x, y: value.location.y - 120)
                    if gridRect.contains(hoverPoint) {
                        let cellSize = gridRect.width / CGFloat(gridSize)
                        let col = Int(round((hoverPoint.x - gridRect.minX - cellSize/2) / cellSize))
                        let row = Int(round((hoverPoint.y - gridRect.minY - cellSize/2) / cellSize))
                        onHover(row, col, shape)
                    } else { onHover(0, 0, nil) }
                }
                .onEnded { value in
                    let dropPoint = CGPoint(x: value.location.x, y: value.location.y - 120)
                    if gridRect.contains(dropPoint) {
                        let cellSize = gridRect.width / CGFloat(gridSize)
                        let col = Int(round((dropPoint.x - gridRect.minX - cellSize/2) / cellSize))
                        let row = Int(round((dropPoint.y - gridRect.minY - cellSize/2) / cellSize))
                        onDrop(row, col)
                    }
                    onHover(0, 0, nil)
                    withAnimation(.spring()) { offset = .zero; isDragging = false }
                })
    }
}

struct ShapePreview: View {
    let shape: GameShape, scale: CGFloat
    var body: some View {
        ZStack {
            ForEach(shape.blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: 4).fill(shape.color).frame(width: 30 * scale, height: 30 * scale)
                    .offset(x: block.x * 32 * scale, y: block.y * 32 * scale)
            }
        }
    }
}
