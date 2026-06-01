import SwiftUI

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
