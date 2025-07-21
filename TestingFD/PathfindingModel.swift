import Foundation
import GameplayKit

class EventMapPathfinding: NSObject {
    private var gridGraph: GKGridGraph<GKGridGraphNode>
    private let gridWidth: Int32
    private let gridHeight: Int32
    private var booths: [Booth] = []
    private var crowdData: CrowdData
    
    init(width: Int32, height: Int32, crowdData: CrowdData) {
        self.gridWidth = width
        self.gridHeight = height
        self.crowdData = crowdData
        self.gridGraph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                                     width: width,
                                     height: height,
                                     diagonalsAllowed: false)
        super.init()
        setupInitialBooths()
        updateObstacles()
    }
    
    // MARK: - Setup and Obstacles
    private func setupInitialBooths() {
        // ... (Fungsi ini tetap sama, tidak perlu diubah)
        let sampleBooths = [
            // Central 4-booth section (2x2 large booths forming a big square)
            Booth(name: "Food Court NW", gridPosition: GridPosition(x: 8, y: 6), size: .large, hasBeacon: true),
            Booth(name: "Food Court NE", gridPosition: GridPosition(x: 10, y: 6), size: .large, hasBeacon: false),
            Booth(name: "Food Court SW", gridPosition: GridPosition(x: 8, y: 8), size: .large, hasBeacon: true),
            Booth(name: "Food Court SE", gridPosition: GridPosition(x: 10, y: 8), size: .large, hasBeacon: false),
            
            // Left section - small booths grouped together
            Booth(name: "Tech Booth A", gridPosition: GridPosition(x: 2, y: 4), size: .small, hasBeacon: true),
            Booth(name: "Tech Booth B", gridPosition: GridPosition(x: 3, y: 4), size: .small, hasBeacon: false),
            Booth(name: "Tech Booth C", gridPosition: GridPosition(x: 2, y: 5), size: .small, hasBeacon: false),
            Booth(name: "Tech Booth D", gridPosition: GridPosition(x: 3, y: 5), size: .small, hasBeacon: true),
            
            // Right section - small booths grouped together
            Booth(name: "Gaming Zone A", gridPosition: GridPosition(x: 15, y: 4), size: .small, hasBeacon: true),
            Booth(name: "Gaming Zone B", gridPosition: GridPosition(x: 16, y: 4), size: .small, hasBeacon: false),
            Booth(name: "Gaming Zone C", gridPosition: GridPosition(x: 15, y: 5), size: .small, hasBeacon: false),
            Booth(name: "Gaming Zone D", gridPosition: GridPosition(x: 16, y: 5), size: .small, hasBeacon: true),
            
            // Top section - small booths in a line
            Booth(name: "Info Desk A", gridPosition: GridPosition(x: 7, y: 2), size: .small, hasBeacon: false),
            Booth(name: "Info Desk B", gridPosition: GridPosition(x: 8, y: 2), size: .small, hasBeacon: true),
            Booth(name: "Info Desk C", gridPosition: GridPosition(x: 9, y: 2), size: .small, hasBeacon: false),
            Booth(name: "Info Desk D", gridPosition: GridPosition(x: 10, y: 2), size: .small, hasBeacon: false),
            
            // Bottom section - small booths grouped
            Booth(name: "Art Gallery A", gridPosition: GridPosition(x: 6, y: 12), size: .small, hasBeacon: false),
            Booth(name: "Art Gallery B", gridPosition: GridPosition(x: 7, y: 12), size: .small, hasBeacon: true),
            Booth(name: "Merch Store A", gridPosition: GridPosition(x: 10, y: 12), size: .small, hasBeacon: true),
            Booth(name: "Merch Store B", gridPosition: GridPosition(x: 11, y: 12), size: .small, hasBeacon: false),
            
            // Additional scattered booths for variety
            Booth(name: "Music Stage", gridPosition: GridPosition(x: 4, y: 9), size: .large, hasBeacon: true),
            Booth(name: "Sponsor Booth", gridPosition: GridPosition(x: 13, y: 8), size: .large, hasBeacon: true),
        ]
        
        booths = sampleBooths
        simulateCrowdData()
    }
    
    private func simulateCrowdData() {
        // ... (Fungsi ini tetap sama, tidak perlu diubah)
        for booth in booths where booth.hasBeacon {
            let crowdLevel = Float.random(in: 0.2...0.9)
            crowdData.updateCrowdLevel(at: booth.gridPosition, level: crowdLevel)
            
            for dx in -1...1 {
                for dy in -1...1 {
                    let nearbyPos = GridPosition(x: booth.gridPosition.x + dx, y: booth.gridPosition.y + dy)
                    if isValidPosition(nearbyPos) {
                        let nearbyLevel = crowdLevel * Float.random(in: 0.3...0.7)
                        crowdData.updateCrowdLevel(at: nearbyPos, level: nearbyLevel)
                    }
                }
            }
        }
    }
    
    private func updateObstacles() {
        // ... (Fungsi ini tetap sama, tidak perlu diubah)
        var obstacles: [GKGridGraphNode] = []
        
        for booth in booths {
            let positions = getBoothOccupiedPositions(booth)
            for position in positions {
                if let node = gridGraph.node(atGridPosition: vector_int2(Int32(position.x), Int32(position.y))) {
                    obstacles.append(node)
                }
            }
        }
        
        gridGraph.remove(obstacles)
    }
    
    // MARK: - Booth Information
    func getBooths() -> [Booth] {
        return booths
    }
    
    func getBoothOccupiedPositions(_ booth: Booth) -> [GridPosition] {
        // ... (Fungsi ini tetap sama, tidak perlu diubah)
        var positions: [GridPosition] = []
        
        switch booth.size {
        case .small:
            positions.append(booth.gridPosition)
        case .large:
            for dx in 0..<2 {
                for dy in 0..<2 {
                    positions.append(GridPosition(x: booth.gridPosition.x + dx, y: booth.gridPosition.y + dy))
                }
            }
        }
        
        return positions
    }
    
    private func isValidPosition(_ position: GridPosition) -> Bool {
        return position.x >= 0 && position.x < gridWidth && position.y >= 0 && position.y < gridHeight
    }
    
    // MARK: - Pathfinding Logic
    
    /// **[DIUBAH]** Fungsi ini sekarang public agar bisa dipanggil dari View.
    /// Mencari semua titik di sekitar booth yang bisa diakses (bukan obstacle).
    func findAccessPoints(for booth: Booth) -> [GridPosition] {
        var accessPoints: [GridPosition] = []
        let occupiedPositions = getBoothOccupiedPositions(booth)
        let occupiedSet = Set(occupiedPositions)

        for pos in occupiedPositions {
            let neighbors = [
                GridPosition(x: pos.x, y: pos.y - 1),
                GridPosition(x: pos.x, y: pos.y + 1),
                GridPosition(x: pos.x - 1, y: pos.y),
                GridPosition(x: pos.x + 1, y: pos.y)
            ]

            for neighbor in neighbors {
                if isValidPosition(neighbor) && !occupiedSet.contains(neighbor) {
                    if gridGraph.node(atGridPosition: vector_int2(Int32(neighbor.x), Int32(neighbor.y))) != nil {
                        if !accessPoints.contains(neighbor) {
                            accessPoints.append(neighbor)
                        }
                    }
                }
            }
        }
        return accessPoints
    }
    
    /// **[BARU]** Mencari rute dari satu titik awal yang spesifik ke titik akses terdekat dari booth tujuan.
    func findPath(from startPosition: GridPosition, to endBooth: Booth) -> [GridPosition] {
        // 1. Dapatkan semua titik akses untuk booth tujuan.
        let endAccessPoints = findAccessPoints(for: endBooth)

        // Pastikan titik awal valid dan booth tujuan punya titik akses.
        guard let startNode = gridGraph.node(atGridPosition: vector_int2(Int32(startPosition.x), Int32(startPosition.y))),
              !endAccessPoints.isEmpty else {
            print("Posisi awal tidak valid atau tidak ada titik akses untuk booth tujuan.")
            return []
        }

        var shortestPath: [GKGridGraphNode] = []

        // 2. Iterasi semua titik akses tujuan untuk menemukan rute terpendek.
        for endPoint in endAccessPoints {
            guard let endNode = gridGraph.node(atGridPosition: vector_int2(Int32(endPoint.x), Int32(endPoint.y))) else {
                continue
            }

            // Hitung rute untuk kombinasi ini
            let currentPathNodes = gridGraph.findPath(from: startNode, to: endNode) as! [GKGridGraphNode]

            // 3. Jika rute ditemukan, bandingkan dengan rute terpendek yang sudah ada.
            if !currentPathNodes.isEmpty {
                if shortestPath.isEmpty || currentPathNodes.count < shortestPath.count {
                    shortestPath = currentPathNodes
                }
            }
        }
        
        // 4. Konversi hasil node kembali ke [GridPosition]
        let gridPath = shortestPath.map { node -> GridPosition in
            return GridPosition(x: Int(node.gridPosition.x), y: Int(node.gridPosition.y))
        }

        return gridPath
    }
}
