import Foundation
import SwiftUI

struct Block: Identifiable, Codable, Equatable {
    let id: UUID
    var color: Color
    
    init(id: UUID = UUID(), color: Color = .blue) {
        self.id = id
        self.color = color
    }
}

struct GameShape: Identifiable {
    let id = UUID()
    let blocks: [CGPoint] // Local coordinates within the shape grid
    let color: Color
    
    static let templates: [GameShape] = [
        // Monomino
        GameShape(blocks: [CGPoint(x: 0, y: 0)], color: .blue),
        // Domino
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)], color: .cyan),
        // Tromino L
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)], color: .orange),
        // Tromino I
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)], color: .purple),
        // Tetrimino O
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)], color: .yellow),
        // Tetrimino I
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0)], color: .red),
        // Big L
        GameShape(blocks: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 2), CGPoint(x: 1, y: 2)], color: .green),
    ]
    
    static func random() -> GameShape {
        templates.randomElement()!
    }
}
