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

@MainActor
class GameViewModel: ObservableObject {
    @Published var grid: [[Color?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @Published var currentShapes: [GameShape?] = []
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    @Published var combo: Int = 0
    @Published var previewInfo: (row: Int, col: Int, shape: GameShape)?
    
    init() {
        startNewRound()
    }
    
    func setPreview(row: Int, col: Int, shape: GameShape?) {
        if let shape = shape {
            previewInfo = (row, col, shape)
        } else {
            previewInfo = nil
        }
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

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var gridRect: CGRect = .zero
    
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("BLOCK BLAST").font(.system(.caption, design: .rounded)).bold().foregroundStyle(.gray)
                        Text("\(vm.score)").font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    if vm.combo > 0 {
                        VStack {
                            Text("COMBO").font(.caption.bold()).foregroundStyle(.orange)
                            Text("x\(vm.combo)").font(.title2.bold()).foregroundStyle(.orange)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                // Grid
                ZStack {
                    GridView(grid: vm.grid, preview: vm.previewInfo, canPlace: vm.canPlace)
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
                }
                .padding(16)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))
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
        .overlay {
            if vm.isGameOver {
                gameOverOverlay
            }
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("GAME OVER").font(.system(size: 54, weight: .black, design: .rounded)).foregroundStyle(.white)
                VStack(spacing: 8) {
                    Text("Score").font(.headline).foregroundStyle(.gray)
                    Text("\(vm.score)").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
                Button {
                    withAnimation { vm.reset() }
                } label: {
                    Text("TRY AGAIN")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 18)
                        .background(Color.blue, in: Capsule())
                        .shadow(color: .blue.opacity(0.4), radius: 10)
                }
            }
        }
    }
}

struct GridView: View {
    let grid: [[Color?]]
    let preview: (row: Int, col: Int, shape: GameShape)?
    let canPlace: (GameShape, Int, Int) -> Bool
    
    var body: some View {
        AspectRatioContainer(aspectRatio: 1) {
            ZStack {
                // Base Grid
                VStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 4) {
                            ForEach(0..<8, id: \.self) { c in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(grid[r][c] ?? Color.white.opacity(0.08))
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
                                        RoundedRectangle(cornerRadius: 4)
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
        ShapePreview(shape: shape, scale: isDragging ? 1.0 : 0.55)
            .offset(offset)
            .zIndex(isDragging ? 10 : 1)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        // Offset it up so it's visible above the finger
                        offset = CGSize(width: value.translation.width, height: value.translation.height - 80)
                        
                        // Calculate hover position
                        // We use the finger location and adjust for the fact that the shape is offset upwards
                        let hoverPoint = CGPoint(x: value.location.x, y: value.location.y - 80)
                        
                        if gridRect.contains(hoverPoint) {
                            let cellSize = gridRect.width / 8
                            let localX = hoverPoint.x - gridRect.minX
                            let localY = hoverPoint.y - gridRect.minY
                            
                            // Align the shape so it feels like it's being held by its "center"
                            // For simplicity, we align the top-left block (0,0) to the nearest cell
                            let col = Int(round((localX - cellSize/2) / cellSize))
                            let row = Int(round((localY - cellSize/2) / cellSize))
                            
                            onHover(row, col, shape)
                        } else {
                            onHover(0, 0, nil)
                        }
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
