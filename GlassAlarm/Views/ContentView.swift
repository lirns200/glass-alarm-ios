import SwiftUI
import Foundation

// MARK: - Models
struct GameShape: Identifiable {
    let id = UUID()
    let blocks: [CGPoint]
    let color: Color
    
    static let templates: [GameShape] = [
        GameShape(blocks: [CGPoint(x: 0, y: 0)], color: .blue),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)], color: .cyan),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)], color: .orange),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)], color: .purple),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)], color: .yellow),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0)], color: .red),
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 2), CGPoint(x: 1, y: 2)], color: .green),
    ]
    
    static func random() -> GameShape {
        templates.randomElement()!
    }
}

@MainActor
class GameViewModel: ObservableObject {
    @Published var grid: [[Color?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @Published var currentShapes: [GameShape?] = []
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    @Published var combo: Int = 0
    
    init() {
        startNewRound()
    }
    
    func startNewRound() {
        currentShapes = [GameShape.random(), GameShape.random(), GameShape.random()]
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
        for block in shape.blocks {
            let r = row + Int(block.y)
            let c = col + Int(block.x)
            grid[r][c] = shape.color
        }
        if let index = currentShapes.firstIndex(where: { $0?.id == shape.id }) {
            currentShapes[index] = nil
        }
        clearLines()
        if currentShapes.allSatisfy({ $0 == nil }) {
            startNewRound()
        }
        checkGameOver()
    }
    
    private func clearLines() {
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
            score += (linesCleared * 10 + (combo - 1) * 5) * linesCleared
            for r in rowsToClear { for c in 0..<8 { grid[r][c] = nil } }
            for c in colsToClear { for r in 0..<8 { grid[r][c] = nil } }
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
        isGameOver = true
    }
    
    func reset() {
        grid = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        score = 0; combo = 0; isGameOver = false; startNewRound()
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var gridRect: CGRect = .zero
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.12, blue: 0.15).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("SCORE").font(.caption.bold()).foregroundStyle(.gray)
                        Text("\(vm.score)").font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    if vm.combo > 1 {
                        Text("COMBO x\(vm.combo)").font(.headline.bold()).foregroundStyle(.orange)
                            .padding(8).background(Color.orange.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
                
                // Grid
                GridView(grid: vm.grid)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                gridRect = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { newFrame in
                                gridRect = newFrame
                            }
                        }
                    )
                    .padding(16)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                
                // Dock
                HStack(spacing: 20) {
                    ForEach(vm.currentShapes.indices, id: \.self) { i in
                        if let shape = vm.currentShapes[i] {
                            DraggableShapeView(shape: shape, gridRect: gridRect) { row, col in
                                vm.place(shape: shape, at: row, col: col)
                            }
                        } else {
                            Color.clear.frame(width: 80, height: 80)
                        }
                    }
                }
                .frame(height: 120)
                
                Spacer()
            }
            .padding(.top, 20)
            
            if vm.isGameOver {
                gameOverOverlay
            }
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("GAME OVER").font(.system(size: 48, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("Final Score: \(vm.score)").font(.title2).foregroundStyle(.white.opacity(0.8))
                Button { vm.reset() } label: {
                    Text("TRY AGAIN").font(.headline.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 40).padding(.vertical, 16).background(Color.blue, in: Capsule())
                }
            }
        }
    }
}

struct GridView: View {
    let grid: [[Color?]]
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(grid[r][c] ?? Color.white.opacity(0.1))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

struct DraggableShapeView: View {
    let shape: GameShape
    let gridRect: CGRect
    let onDrop: (Int, Int) -> Void
    
    @State private var offset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        ShapePreview(shape: shape, scale: isDragging ? 1.0 : 0.6)
            .offset(offset)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        isDragging = true
                        offset = value.translation
                    }
                    .onEnded { value in
                        if gridRect.contains(value.location) {
                            let cellSize = gridRect.width / 8
                            let localX = value.location.x - gridRect.minX
                            let localY = value.location.y - gridRect.minY
                            let col = Int(floor(localX / cellSize))
                            let row = Int(floor(localY / cellSize))
                            onDrop(row, col)
                        }
                        withAnimation(.spring()) {
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
            ForEach(0..<shape.blocks.count, id: \.self) { i in
                let block = shape.blocks[i]
                RoundedRectangle(cornerRadius: 4)
                    .fill(shape.color)
                    .frame(width: 30 * scale, height: 30 * scale)
                    .offset(x: block.x * 32 * scale, y: block.y * 32 * scale)
            }
        }
        .frame(width: 80, height: 80)
    }
}
