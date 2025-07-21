import SwiftUI

struct EventMapView: View {
    @StateObject private var crowdData = CrowdData()
    @State private var pathfinding: EventMapPathfinding?
    
    @State private var selectedStartBooth: Booth?
    @State private var selectedStartPosition: GridPosition?
    @State private var selectedEndBooth: Booth?
    @State private var highlightedAccessPoints: [GridPosition] = []
    
    @State private var currentPath: [GridPosition] = []
    @State private var currentCheckpointIndex: Int = 0
    
    // Properti tampilan peta
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let gridSize: CGFloat = 40
    private let mapWidth: Int32 = 20
    private let mapHeight: Int32 = 16
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // map ui
            mapContent
                .scaleEffect(scale)
                .gesture(
                    SimultaneousGesture(
                        // gesture -> pinch in out zoom
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.5, min(3.0, value))
                            },
                        
                        // Drag -> Geser jari
                        DragGesture()
                            .onChanged { value in
                                // posisi geser sementara saat jari bergerak
                                offset = value.translation
                            }
                        
                        // posisi geser permanen saat jari udah ga gerakin
                            .onEnded { value in
                                lastOffset.width += offset.width
                                lastOffset.height += offset.height
                                offset = .zero
                            }
                    )
                )
            
            VStack {
                HStack {
                    controlPanel
                        .offset(x : -10)
                }
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            setupPathfinding()
        }
    }

    // Map Content Views
    private var mapContent: some View {
        ZStack {
            
            // Konten2 yang ada dalem peta
            gridBackground // -> Grid abu abu putih kotak2
            crowdHeatmap // -> Warna merah transparant, crowd heatmap masih ngasal
            accessPointsHighlightView // Titik akses booth awal
            boothsView // -> Visualisasi booth
            pathView // -> Jalur dari start - end
        }
        .frame(width: CGFloat(mapWidth) * gridSize, height: CGFloat(mapHeight) * gridSize)
    }

    private var gridBackground: some View {
        VStack(spacing: 0) {
            ForEach(0..<Int(mapHeight), id: \.self) { y in
                HStack(spacing: 0) {
                    ForEach(0..<Int(mapWidth), id: \.self) { x in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: gridSize, height: gridSize)
                            .border(Color.gray.opacity(0.2), width: 0.5)
                    }
                }
            }
        }
    }

    private var crowdHeatmap: some View {
        
        ForEach(Array(crowdData.crowdLevels.keys), id: \.self) { position in
            let crowdLevel = crowdData.getCrowdLevel(at: position)
            Rectangle()
                .fill(Color.red.opacity(Double(crowdLevel * 0.5)))
                .frame(width: gridSize, height: gridSize)
                .position(x: CGFloat(position.x) * gridSize + gridSize/2,
                          y: CGFloat(position.y) * gridSize + gridSize/2)
        }
    }
    
    private var accessPointsHighlightView: some View {
        
        // Di sini ada selected start point, hijau bisa klik untuk mulai & kalau udah di klik tapi blom cari rute dia warnanya jadi kuning
        
        ZStack {
            ForEach(highlightedAccessPoints, id: \.self) { pos in
               
                let isSelectedPoint = (pos == selectedStartPosition)
                
                Rectangle()
                    .fill(isSelectedPoint ? Color.yellow.opacity(0.7) : Color.green.opacity(0.6))
                    .overlay(
                        Rectangle()
                            .stroke(isSelectedPoint ? Color.orange : Color.clear, lineWidth: 2)
                    )
                    .frame(width: gridSize, height: gridSize)
                    .position(point(for: pos))
                    .onTapGesture {
                        selectStartPosition(pos)
                    }
            }
        }
    }

    private var boothsView: some View {
        ZStack {
            if let pathfinding = pathfinding {
                ForEach(pathfinding.getBooths(), id: \.id) { booth in
                    boothView(booth)
                }
            }
        }
    }

    private func boothView(_ booth: Booth) -> some View {
        let size = booth.size == .large ? gridSize * 2 : gridSize
        
        let isStagedForStart = selectedStartBooth?.id == booth.id && selectedStartPosition == nil
        let isEnd = selectedEndBooth?.id == booth.id
        
        let color: Color = {
            if isEnd { return .red }
            if isStagedForStart { return .green }
            if selectedStartBooth?.id == booth.id && selectedStartPosition != nil { return .blue }
            return .blue
        }()
        
        let occupiedPositions = pathfinding?.getBoothOccupiedPositions(booth) ?? [booth.gridPosition]
        let boothCenterX = CGFloat(occupiedPositions.map { $0.x }.reduce(0, +)) / CGFloat(occupiedPositions.count)
        let boothCenterY = CGFloat(occupiedPositions.map { $0.y }.reduce(0, +)) / CGFloat(occupiedPositions.count)
        
        let position = CGPoint(
            x: (boothCenterX * gridSize) + (booth.size == .large ? gridSize : gridSize / 2),
            y: (boothCenterY * gridSize) + (booth.size == .large ? gridSize : gridSize / 2)
        )

        return RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                VStack {
                    Text(booth.name)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if booth.hasBeacon {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
                .padding(2)
            )
            .position(position)
            .onTapGesture {
                selectBooth(booth)
            }
    }
    
    private var pathView: some View {
        // jalur dari start ke tujuan
        // visited -> abu | jalur belum dilalui -> garis biru putus | titik belok -> check point
        ZStack {
            if !currentPath.isEmpty && currentCheckpointIndex > 0 {
                Path { path in
                    let visitedPath = Array(currentPath[0...currentCheckpointIndex])
                    let firstPoint = point(for: visitedPath[0])
                    path.move(to: firstPoint)
                    for position in visitedPath.dropFirst() {
                        path.addLine(to: point(for: position))
                    }
                }
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            
            if !currentPath.isEmpty && currentCheckpointIndex < currentPath.count - 1 {
                Path { path in
                    let upcomingPath = Array(currentPath[currentCheckpointIndex...])
                    let firstPoint = point(for: upcomingPath[0])
                    path.move(to: firstPoint)
                    for position in upcomingPath.dropFirst() {
                        path.addLine(to: point(for: position))
                    }
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [10, 5]))
            }
            
            ForEach(Array(currentPath.enumerated()), id: \.offset) { index, position in
                if isTurningPoint(at: index, in: currentPath) {
                    let isCurrentCheckpoint = (index == currentCheckpointIndex)
                    let hasBeenVisited = (index < currentCheckpointIndex)
                    
                    Circle()
                        .fill(hasBeenVisited ? Color.gray : Color.blue)
                        .frame(width: isCurrentCheckpoint ? 18 : 12, height: isCurrentCheckpoint ? 18 : 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 3)
                        .position(point(for: position))
                        .onTapGesture {
                            withAnimation(.spring()) {
                                currentCheckpointIndex = index
                            }
                        }
                }
            }
        }
    }

    // Control Panels -> Mulai ... Tujuan ... -> Menghitung jalur & reset semua pilihan & map
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Navigasi Event")
                    .font(.headline)
                
                VStack(alignment: .leading) {
                    Text("Mulai: \(startPointText())")
                        .foregroundColor(selectedStartPosition == nil ? .gray : .primary)
                    Text("Tujuan: \(selectedEndBooth?.name ?? "Pilih booth tujuan")")
                        .foregroundColor(selectedEndBooth == nil ? .gray : .primary)
                }
                .font(.subheadline)
                
                HStack {
                    Button("Cari Rute") {
                        calculateRoute()
                    }
                    .disabled(selectedStartPosition == nil || selectedEndBooth == nil)
                    .buttonStyle(.borderedProminent)
                    
                    Button("Bersihkan") {
                        clearSelection()
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Kontrol Peta").font(.headline)
                HStack {
                    Button(action: resetMapPosition) { Image(systemName: "house.fill") } // reset zoom & posisi
                    Button(action: zoomIn) { Image(systemName: "plus.magnifyingglass") } // zoom in
                    Button(action: zoomOut) { Image(systemName: "minus.magnifyingglass") } // zoom out
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(radius: 5)
    }

    // ubah posisi dalam bentuk koordinat grid jadi titik2 pixel real biar bisa ditampilkan di view
    private func point(for position: GridPosition) -> CGPoint {
        return CGPoint(
            x: CGFloat(position.x) * gridSize + gridSize/2,
            y: CGFloat(position.y) * gridSize + gridSize/2
        )
    }
    
    // Menentukan apakah suatu jalur path adalah titik belok -> buat checkpoint
    // Logika -> Ambil titik sebelumnya, saat ini, dan berikutnya
    //      -> Lalu dihitung perbedaan arah dx dy dari dua segmen tadi
    
    private func isTurningPoint(at index: Int, in path: [GridPosition]) -> Bool {
        if index == 0 || index == path.count - 1 { return true }
        guard path.count >= 3 else { return false }
        
        let previous = path[index - 1]
        let current = path[index]
        let next = path[index + 1]
        
        let dx1 = current.x - previous.x
        let dy1 = current.y - previous.y
        let dx2 = next.x - current.x
        let dy2 = next.y - current.y
        
        return dx1 != dx2 || dy1 != dy2
    }
    
    // Menghasilkan teks berdasarkan status pemilihan titik awal untuk ditampilkan di panel kontrol
    
    private func startPointText() -> String {
        if selectedStartPosition != nil {
            return "Posisi Awal Terpilih"
        }
        if let startBooth = selectedStartBooth {
            return "Pilih titik hijau dekat \(startBooth.name)"
        }
        return "Ketuk sebuah booth"
    }
    
    // Membuat instance dari objek EventMapPathFinding, merupakan algo rute shortest path + crowd aware
    private func setupPathfinding() {
        pathfinding = EventMapPathfinding(width: mapWidth, height: mapHeight, crowdData: crowdData)
    }

    // Logic buat clicking booth di maps
    private func selectBooth(_ booth: Booth) {
        if selectedStartPosition == nil {
            if selectedStartBooth?.id == booth.id {
                clearSelection()
            } else {
                selectedStartBooth = booth
                selectedEndBooth = nil
                clearPath()
                
                if let pf = pathfinding {
                    highlightedAccessPoints = pf.findAccessPoints(for: booth)
                }
            }
        }
        else if booth.id != selectedStartBooth?.id {
            withAnimation {
                selectedEndBooth = booth
            }
        }
    }
    
    // Saat user click titik starting hijau -> dipilih sebagai starting point
    private func selectStartPosition(_ position: GridPosition) {
        withAnimation {
            selectedStartPosition = position
            // highlightedAccessPoints = [] // <-- BARIS INI DIHAPUS
        }
    }

    // hitung shortest path dari starting - end route
    private func calculateRoute() {
        guard let startPos = selectedStartPosition,
              let endBooth = selectedEndBooth,
              let pathfinding = pathfinding else { return }
        
        let path = pathfinding.findPath(from: startPos, to: endBooth)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPath = path
            currentCheckpointIndex = 0
            highlightedAccessPoints = [] // <-- BARIS INI DIPINDAHKAN KE SINI
        }
    }

    // reset
    private func clearSelection() {
        withAnimation {
            selectedStartBooth = nil
            selectedStartPosition = nil
            selectedEndBooth = nil
            highlightedAccessPoints = []
            clearPath()
        }
    }
    
    // hanya hapus path & checkpoint, bukan booth dipilih
    private func clearPath() {
        currentPath = []
        currentCheckpointIndex = 0
    }

    // reset map position ke default habis di zoom zoom
    private func resetMapPosition() {
        withAnimation(.easeInOut) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    // zoom in out
    
    private func zoomIn() {
        withAnimation(.easeInOut) {
            scale = min(3.0, scale * 1.3)
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut) {
            scale = max(0.5, scale / 1.3)
        }
    }
}


#Preview {
    EventMapView()
}
