import Foundation
import GameplayKit

class EventMapPathfinding: NSObject, ObservableObject {
    private var gridGraph: GKGridGraph<GKGridGraphNode>
    private let gridWidth: Int32
    private let gridHeight: Int32
    var crowdData: CrowdData // Change from private var to var so it can be accessed
    
    // Pathfinding state
    @Published var currentPath: [GKGridGraphNode] = []
    @Published var startPoint: GridPosition?
    @Published var endPoint: GridPosition?
    @Published var isSelectingStart = false
    @Published var isSelectingEnd = false
    @Published var pathfindingMode = false
    
    // Hall configurations
    struct HallConfig {
        let yStart: Int
        let yEnd: Int
        let width: Int
        let height: Int
        let hall: Hall
    }
    
    private let hallConfigs: [HallConfig] = [
        HallConfig(yStart: 0, yEnd: 7, width: 9, height: 8, hall: .hallC),    // Hall C (Top)
        HallConfig(yStart: 8, yEnd: 15, width: 12, height: 8, hall: .hallB),  // Hall B (Middle)  
        HallConfig(yStart: 16, yEnd: 21, width: 10, height: 6, hall: .hallA)  // Hall A (Bottom)
    ]
    
    init(width: Int32, height: Int32, crowdData: CrowdData) {
        self.gridWidth = width
        self.gridHeight = height
        self.crowdData = crowdData
        self.gridGraph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                                     width: width,
                                     height: height,
                                     diagonalsAllowed: false)
        super.init()
        setupWalkablePaths()
    }
    
    func setupWalkablePaths() {
        var nodesToRemove: [GKGridGraphNode] = []
        
        // Remove nodes where booths are located
        for booth in crowdData.booths {
            let boothNodes = getBoothOccupiedNodes(booth: booth)
            nodesToRemove.append(contentsOf: boothNodes)
        }
        
        // Remove nodes outside hall boundaries
        for node in gridGraph.nodes! {
            if let gridNode = node as? GKGridGraphNode {
                let position = GridPosition(x: Int(gridNode.gridPosition.x), y: Int(gridNode.gridPosition.y))
                if !isValidPathPosition(position) {
                    nodesToRemove.append(gridNode)
                }
            }
        }
        
        gridGraph.remove(nodesToRemove)
    }
    
    private func getBoothOccupiedNodes(booth: Booth) -> [GKGridGraphNode] {
        var nodes: [GKGridGraphNode] = []
        let is2x2 = booth.name.contains("2x2")
        
        if is2x2 {
            // 2x2 booth occupies 4 positions
            for dx in 0..<2 {
                for dy in 0..<2 {
                    let x = Int32(booth.gridPosition.x + dx)
                    let y = Int32(booth.gridPosition.y + dy)
                    if let node = gridGraph.node(atGridPosition: vector_int2(x, y)) {
                        nodes.append(node)
                    }
                }
            }
        } else {
            // 1x1 booth occupies 1 position
            let x = Int32(booth.gridPosition.x)
            let y = Int32(booth.gridPosition.y)
            if let node = gridGraph.node(atGridPosition: vector_int2(x, y)) {
                nodes.append(node)
            }
        }
        
        return nodes
    }
    
    private func isValidPathPosition(_ position: GridPosition) -> Bool {
        // Check if position is within any hall
        for config in hallConfigs {
            let leftPadding = (Int(gridWidth) - config.width) / 2
            let rightBound = leftPadding + config.width
            
            if position.x >= leftPadding && position.x < rightBound &&
               position.y >= config.yStart && position.y <= config.yEnd {
                return true
            }
        }
        return false
    }
    
    // Get valid path positions adjacent to a booth
    func getAdjacentPathPositions(for booth: Booth) -> [GridPosition] {
        var adjacentPositions: [GridPosition] = []
        let is2x2 = booth.name.contains("2x2")
        
        let positions = is2x2 ? 
            [(0, 0), (0, 1), (1, 0), (1, 1)] : // 2x2 booth positions
            [(0, 0)] // 1x1 booth position
        
        for (dx, dy) in positions {
            let boothX = booth.gridPosition.x + dx
            let boothY = booth.gridPosition.y + dy
            
            // Check all 4 directions around each booth cell
            let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
            for (dirX, dirY) in directions {
                let adjX = boothX + dirX
                let adjY = boothY + dirY
                let adjPosition = GridPosition(x: adjX, y: adjY)
                
                // Check if this position is valid and walkable
                if isValidPathPosition(adjPosition) && isWalkablePosition(adjPosition) {
                    if !adjacentPositions.contains(adjPosition) {
                        adjacentPositions.append(adjPosition)
                    }
                }
            }
        }
        
        return adjacentPositions
    }
    
    private func isWalkablePosition(_ position: GridPosition) -> Bool {
        let node = gridGraph.node(atGridPosition: vector_int2(Int32(position.x), Int32(position.y)))
        return node != nil
    }
    
    // Pathfinding functions
    func findPath(from start: GridPosition, to end: GridPosition) -> [GridPosition] {
        guard let startNode = gridGraph.node(atGridPosition: vector_int2(Int32(start.x), Int32(start.y))),
              let endNode = gridGraph.node(atGridPosition: vector_int2(Int32(end.x), Int32(end.y))) else {
            return []
        }
        
        let path = gridGraph.findPath(from: startNode, to: endNode) as? [GKGridGraphNode] ?? []
        
        return path.map { node in
            GridPosition(x: Int(node.gridPosition.x), y: Int(node.gridPosition.y))
        }
    }
    
    func startPathfinding() {
        pathfindingMode = true
        isSelectingStart = true
        isSelectingEnd = false
        clearPath()
    }
    
    func stopPathfinding() {
        pathfindingMode = false
        isSelectingStart = false
        isSelectingEnd = false
        clearPath()
    }
    
    // Update the setStartPoint function to not automatically set isSelectingEnd
    func setStartPoint(_ position: GridPosition) {
        startPoint = position
        // Don't automatically set isSelectingEnd since we're not using that flow anymore
        updatePath()
    }
    
    // Update the setEndPoint function similarly
    func setEndPoint(_ position: GridPosition) {
        endPoint = position
        updatePath()
    }
    
    func selectBoothAsDestination(_ booth: Booth) {
        let adjacentPositions = getAdjacentPathPositions(for: booth)
        if let closestPosition = findClosestPosition(to: booth.gridPosition, from: adjacentPositions) {
            setEndPoint(closestPosition)
        }
    }
    
    // Make this function public by removing private
    func findClosestPosition(to target: GridPosition, from positions: [GridPosition]) -> GridPosition? {
        return positions.min { pos1, pos2 in
            let dist1 = abs(pos1.x - target.x) + abs(pos1.y - target.y)
            let dist2 = abs(pos2.x - target.x) + abs(pos2.y - target.y)
            return dist1 < dist2
        }
    }
    
    private func updatePath() {
        guard let start = startPoint, let end = endPoint else {
            currentPath = []
            return
        }
        
        let pathPositions = findPath(from: start, to: end)
        currentPath = pathPositions.compactMap { position in
            gridGraph.node(atGridPosition: vector_int2(Int32(position.x), Int32(position.y)))
        }
    }
    
    // Make this function public by removing private
    func clearPath() {
        currentPath = []
        startPoint = nil
        endPoint = nil
    }
    
    // Existing functions
    func getHallConfig(for hall: Hall) -> HallConfig? {
        return hallConfigs.first { $0.hall == hall }
    }
    
    func getAllHallConfigs() -> [HallConfig] {
        return hallConfigs
    }
}
