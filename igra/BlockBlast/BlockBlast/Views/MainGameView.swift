import SwiftUI

private class BlockBlastIPChecker: ObservableObject {
    @Published var isYukuVPN: Bool = false
    
    let yukuIPs: Set<String> = [
        "144.31.14.206",
        "94.156.179.163",
        "144.31.79.78",
        "2.26.7.25",
        "51.250.38.20",
        "158.160.86.13",
        "185.133.173.106",
        "167.17.180.164"
    ]
    
    func checkIP() {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let ip = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.isYukuVPN = self.yukuIPs.contains(ip)
                }
            }
        }.resume()
    }
}

struct MainGameView: View {
    @StateObject private var vm = GameViewModel()
    @StateObject private var ipChecker = BlockBlastIPChecker()
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.12, blue: 0.15).ignoresSafeArea()
            
            VStack(spacing: 30) {
                if ipChecker.isYukuVPN {
                    Text("YUKU VPN")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.top, 10)
                }
                
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("SCORE")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        Text("\(vm.score)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if vm.combo > 1 {
                        Text("COMBO x\(vm.combo)")
                            .font(.headline.bold())
                            .foregroundStyle(.orange)
                            .padding(8)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
                
                // Grid
                GridView(grid: vm.grid)
                    .padding(16)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                
                // Dock (Shapes)
                HStack(spacing: 20) {
                    ForEach(vm.currentShapes.indices, id: \.self) { i in
                        if let shape = vm.currentShapes[i] {
                            DraggableShapeView(shape: shape) { row, col in
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
        .onAppear {
            ipChecker.checkIP()
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Final Score: \(vm.score)")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                
                Button {
                    vm.reset()
                } label: {
                    Text("TRY AGAIN")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.blue, in: Capsule())
                }
            }
        }
    }
}

struct GridView: View {
    let grid: [[Color?]]
    let cellSize: CGFloat = (UIScreen.main.bounds.width - 64) / 8
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(grid[r][c] ?? Color.white.opacity(0.1))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }
}

struct DraggableShapeView: View {
    let shape: GameShape
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
                        // Basic hit detection (simplified for this demo)
                        // In a real app, you'd calculate the grid cell from the drop location
                        let dropLoc = value.location
                        // Assuming grid center for this mock-up logic
                        // This logic should be improved for real play
                        let gridRow = 4 // Mock
                        let gridCol = 4 // Mock
                        
                        // Check if dropped near grid (dummy check)
                        if abs(offset.height) > 100 {
                             onDrop(gridRow, gridCol)
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
            ForEach(shape.blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: 4)
                    .fill(shape.color)
                    .frame(width: 30 * scale, height: 30 * scale)
                    .offset(x: block.x * 32 * scale, y: block.y * 32 * scale)
            }
        }
        .frame(width: 80, height: 80)
    }
}
