import SwiftUI

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var gridRect: CGRect = .zero
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.1).ignoresSafeArea()
            
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
                    GridView(grid: vm.grid)
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
                                DraggableShapeView(shape: shape, gridRect: gridRect) { row, col in
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
    
    var body: some View {
        AspectRatioContainer(aspectRatio: 1) {
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
                            // Offset it up a bit so it's visible above the finger
                            offset = CGSize(width: value.translation.width, height: value.translation.height - 60)
                        } else {
                            offset = CGSize(width: value.translation.width, height: value.translation.height - 60)
                        }
                    }
                    .onEnded { value in
                        let dropPoint = value.location
                        
                        if gridRect.contains(dropPoint) {
                            let cellSize = gridRect.width / 8
                            let localX = dropPoint.x - gridRect.minX
                            let localY = dropPoint.y - gridRect.minY
                            
                            // Center the shape on the grid
                            // Since ShapePreview centers the blocks around 0,0 (mostly), 
                            // we need to be careful with indexing.
                            // Assuming block 0,0 is the top-left-most block of the shape.
                            
                            let col = Int(floor(localX / cellSize))
                            let row = Int(floor(localY / cellSize))
                            
                            onDrop(row, col)
                        }
                        
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
                    .frame(width: 30 * scale, height: 30 * scale)
                    .offset(x: block.x * 32 * scale, y: block.y * 32 * scale)
            }
        }
        .frame(width: 80, height: 80)
    }
}
