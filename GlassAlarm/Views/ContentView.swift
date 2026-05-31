import SwiftUI

struct GameShape: Identifiable {
    let id = UUID()
    let blocks: [CGPoint]
    let color: Color
    
    static let templates: [GameShape] = [
        // 1-block
        GameShape(blocks: [CGPoint(x: 0, y: 0)], color: .blue),
        
        // 2-blocks
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)], color: .cyan),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1)], color: .cyan),
        
        // 3-blocks
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)], color: .purple),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 2)], color: .purple),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1)], color: .orange),
        
        // 4-blocks
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0)], color: .red),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 2), CGPoint(x: 0, y: 3)], color: .red),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)], color: .yellow),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 1, y: 1)], color: .pink),
        
        // 5-blocks
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
    @Published var isGameOver: Bool = false
    @Published var combo: Int = 0
    @Published var previewInfo: (row: Int, col: Int, shape: GameShape)?
    @Published var popups: [ScorePopup] = []
    
    // Settings
    @Published var isSoundEnabled: Bool = true
    @Published var isVibrationEnabled: Bool = true
    @Published var isDarkMode: Bool = true
    
    init() {
        startNewRound()
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
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
        
        if isVibrationEnabled {
            triggerPlacementFeedback()
        }
        
        for block in shape.blocks {
            let r = row + Int(block.y)
            let c = col + Int(block.x)
            grid[r][c] = shape.color
        }
        
        if let index = currentShapes.firstIndex(where: { $0?.id == shape.id }) {
            currentShapes[index] = nil
        }
        
        clearLines(at: row, col: col)
        
        if currentShapes.allSatisfy({ $0 == nil }) {
            startNewRound()
        }
        checkGameOver()
    }
    
    private func triggerPlacementFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    private func clearLines(at lastRow: Int, col lastCol: Int) {
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
            
            withAnimation(.spring()) {
                score += points
            }
            
            // Add popup near the placement
            let popup = ScorePopup(score: points, position: CGPoint(x: CGFloat(lastCol) * 40, y: CGFloat(lastRow) * 40))
            popups.append(popup)
            
            // Remove popup after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.popups.removeAll { $0.id == popup.id }
            }
            
            for r in rowsToClear { for c in 0..<8 { grid[r][c] = nil } }
            for c in colsToClear { for r in 0..<8 { grid[r][c] = nil } }
        } else {
            combo = 0
        }
    }
    
    private func checkGameOver() {
        for shape in currentShapes.compactMap({ $0 }) {
            for r in 0..<8 {
                for c in 0..<8 {
                    if canPlace(shape: shape, at: r, col: c) { return }
                }
            }
        }
        isGameOver = true
    }
    
    func reset() {
        grid = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        score = 0
        combo = 0
        isGameOver = false
        startNewRound()
    }
    
    var comboColor: Color {
        if combo <= 1 { return .gray }
        if combo <= 5 { return .yellow }
        return .red
    }
}

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var gridRect: CGRect = .zero
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            (vm.isDarkMode ? Color(red: 0.02, green: 0.04, blue: 0.08) : Color(red: 0.95, green: 0.96, blue: 0.98))
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Settings Button Top Right
                HStack {
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
                
                // Centered Score & Combo
                HStack(spacing: 20) {
                    // Combo Left
                    ZStack {
                        if vm.combo > 1 {
                            VStack(spacing: -2) {
                                Text("COMBO")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                Text("x\(vm.combo)")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(vm.comboColor)
                            .padding(8)
                            .background(vm.comboColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 80)
                    
                    // Score Center
                    VStack(spacing: 2) {
                        Text("SCORE")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.gray)
                        Text("\(vm.score)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(vm.isDarkMode ? .white : .black)
                            .contentTransition(.numericText())
                    }
                    
                    Spacer().frame(width: 80) // Balance for combo
                }
                
                // Grid
                ZStack {
                    GridView(grid: vm.grid, preview: vm.previewInfo, canPlace: vm.canPlace, isDarkMode: vm.isDarkMode)
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
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                            .shadow(radius: 2)
                            .position(x: popup.position.x + 20, y: popup.position.y + 20)
                            .transition(.asymmetric(insertion: .scale, removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }
                .padding(16)
                .background(vm.isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                
                // Shapes
                HStack(spacing: 15) {
                    ForEach(vm.currentShapes.indices, id: \.self) { i in
                        ZStack {
                            if let shape = vm.currentShapes[i] {
                                DraggableShapeView(shape: shape, gridRect: gridRect, onHover: { r, c, s in
                                    vm.setPreview(row: r, col: c, shape: s)
                                }) { row, col in
                                    vm.place(shape: shape, at: row, col: col)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            GameSettingsMenuView(vm: vm)
        }
        .overlay {
            if vm.isGameOver {
                gameOverOverlay
            }
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("GAME OVER").font(.system(size: 54, weight: .black, design: .rounded)).foregroundStyle(.white)
                VStack(spacing: 8) {
                    Text("Total Score").font(.headline).foregroundStyle(.gray)
                    Text("\(vm.score)").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
                Button {
                    withAnimation { vm.reset() }
                } label: {
                    Text("TRY AGAIN")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 20)
                        .background(Color.blue, in: Capsule())
                        .shadow(color: .blue.opacity(0.4), radius: 15)
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
                Section("GAMEPLAY") {
                    Toggle("Sound Effects", isOn: $vm.isSoundEnabled)
                    Toggle("Vibration", isOn: $vm.isVibrationEnabled)
                }
                
                Section("APPEARANCE") {
                    Toggle("Dark Mode", isOn: $vm.isDarkMode)
                }
                
                Section("ABOUT") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.3.0").foregroundStyle(.gray)
                    }
                    Text("Block Blast is a logic puzzle where you need to clear the field by building lines.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
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
                // Base Grid
                VStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 4) {
                            ForEach(0..<8, id: \.self) { c in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(grid[r][c] ?? (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 1)
                                    )
                                    .scaleEffect(grid[r][c] != nil ? 1.0 : 0.95)
                            }
                        }
                    }
                }
                
                // Preview Layer
                if let p = preview {
                    let isPossible = canPlace(p.shape, p.row, p.col)
                    VStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { r in
                            HStack(spacing: 4) {
                                ForEach(0..<8, id: \.self) { c in
                                    let isPreviewBlock = p.shape.blocks.contains { block in
                                        Int(block.y) + p.row == r && Int(block.x) + p.col == c
                                    }
                                    
                                    if isPreviewBlock {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isPossible ? p.shape.color.opacity(0.5) : Color.red.opacity(0.3))
                                    } else {
                                        Color.clear
                                    }
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
            let width = geo.size.width
            let height = geo.size.height
            let side = min(width, height)
            
            content()
                .frame(width: side, height: side)
                .position(x: width / 2, y: height / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
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
        ShapePreview(shape: shape, scale: isDragging ? 1.0 : 0.6)
            .offset(offset)
            .zIndex(isDragging ? 10 : 1)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        
                        // Simple subtle offset upward
                        offset = CGSize(width: value.translation.width, height: value.translation.height - 100)
                        
                        let hoverPoint = CGPoint(x: value.location.x, y: value.location.y - 100)
                        if gridRect.contains(hoverPoint) {
                            let cellSize = gridRect.width / 8
                            let localX = hoverPoint.x - gridRect.minX
                            let localY = hoverPoint.y - gridRect.minY
                            let col = Int(round((localX - cellSize/2) / cellSize))
                            let row = Int(round((localY - cellSize/2) / cellSize))
                            onHover(row, col, shape)
                        } else {
                            onHover(0, 0, nil)
                        }
                    }
                    .onEnded { value in
                        let dropPoint = CGPoint(x: value.location.x, y: value.location.y - 100)
                        if gridRect.contains(dropPoint) {
                            let cellSize = gridRect.width / 8
                            let localX = dropPoint.x - gridRect.minX
                            let localY = dropPoint.y - gridRect.minY
                            let col = Int(round((localX - cellSize/2) / cellSize))
                            let row = Int(round((localY - cellSize/2) / cellSize))
                            onDrop(row, col)
                        }
                        
                        onHover(0, 0, nil)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = .zero
                            isDragging = false
                        }
                    }
            )
    }
}

struct ShapePreview: View {
    let shape: GameShape
    let scale: CGFloat
    var body: some View {
        ZStack {
            ForEach(shape.blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: 4)
                    .fill(shape.color)
                    .frame(width: 34 * scale, height: 34 * scale)
                    .offset(x: block.x * 38 * scale, y: block.y * 38 * scale)
            }
        }
    }
}
