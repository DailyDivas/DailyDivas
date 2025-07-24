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
        
        if is2x2 {
            // For 2x2 booths, only check positions directly adjacent to each side
            let boothX = booth.gridPosition.x
            let boothY = booth.gridPosition.y
            
            // Left side of the booth (x-1, y and y+1)
            for dy in 0..<2 {
                let adjPosition = GridPosition(x: boothX - 1, y: boothY + dy)
                if isValidPathPosition(adjPosition) && 
                   isWalkablePosition(adjPosition) && 
                   !adjacentPositions.contains(adjPosition) {
                    adjacentPositions.append(adjPosition)
                }
            }
            
            // Right side of the booth (x+2, y and y+1)
            for dy in 0..<2 {
                let adjPosition = GridPosition(x: boothX + 2, y: boothY + dy)
                if isValidPathPosition(adjPosition) && 
                   isWalkablePosition(adjPosition) && 
                   !adjacentPositions.contains(adjPosition) {
                    adjacentPositions.append(adjPosition)
                }
            }
            
            // Top side of the booth (x and x+1, y-1)
            for dx in 0..<2 {
                let adjPosition = GridPosition(x: boothX + dx, y: boothY - 1)
                if isValidPathPosition(adjPosition) && 
                   isWalkablePosition(adjPosition) && 
                   !adjacentPositions.contains(adjPosition) {
                    adjacentPositions.append(adjPosition)
                }
            }
            
            // Bottom side of the booth (x and x+1, y+2)
            for dx in 0..<2 {
                let adjPosition = GridPosition(x: boothX + dx, y: boothY + 2)
                if isValidPathPosition(adjPosition) && 
                   isWalkablePosition(adjPosition) && 
                   !adjacentPositions.contains(adjPosition) {
                    adjacentPositions.append(adjPosition)
                }
            }
            
        } else {
            // For 1x1 booths, check all 4 adjacent positions
            let boothX = booth.gridPosition.x
            let boothY = booth.gridPosition.y
            
            let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)] // left, right, up, down
            for (dirX, dirY) in directions {
                let adjPosition = GridPosition(x: boothX + dirX, y: boothY + dirY)
                
                if isValidPathPosition(adjPosition) && 
                   isWalkablePosition(adjPosition) && 
                   !adjacentPositions.contains(adjPosition) {
                    adjacentPositions.append(adjPosition)
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
        // Use custom A* for crowd-aware pathfinding
        let pathPositions = findPathWithCrowdAvoidance(from: start, to: end)
        
        // Update currentPath for UI display
        currentPath = pathPositions.compactMap { position in
            gridGraph.node(atGridPosition: vector_int2(Int32(position.x), Int32(position.y)))
        }
        
        return pathPositions
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
        
        // If we have a start point, find the closest adjacent position to the start point
        // This will make the route end on the side closest to where the user is coming from
        if let startPoint = startPoint {
            if let closestPosition = findClosestPosition(to: startPoint, from: adjacentPositions) {
                setEndPoint(closestPosition)
            }
        } else {
            // Fallback: if no start point is set, use the first available adjacent position
            if let firstPosition = adjacentPositions.first {
                setEndPoint(firstPosition)
            }
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
    
    // Add this custom A* implementation to your PathfindingModel.swift
    private func findPathWithCrowdAvoidance(from start: GridPosition, to end: GridPosition) -> [GridPosition] {
        var openSet: [GridPosition] = [start]
        var cameFrom: [GridPosition: GridPosition] = [:]
        var gScore: [GridPosition: Float] = [start: 0]
        var fScore: [GridPosition: Float] = [start: heuristic(start, end)]
        
        while !openSet.isEmpty {
            // Find node with lowest fScore
            let current = openSet.min { fScore[$0, default: Float.infinity] < fScore[$1, default: Float.infinity] }!
            
            if current == end {
                return reconstructPath(cameFrom: cameFrom, current: current)
            }
            
            openSet.removeAll { $0 == current }
            
            // Check all neighbors
            for neighbor in getWalkableNeighbors(of: current) {
                let tentativeGScore = gScore[current, default: Float.infinity] + calculateEdgeWeight(from: current, to: neighbor)
                
                if tentativeGScore < gScore[neighbor, default: Float.infinity] {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeGScore
                    fScore[neighbor] = tentativeGScore + heuristic(neighbor, end)
                    
                    if !openSet.contains(neighbor) {
                        openSet.append(neighbor)
                    }
                }
            }
        }
        
        return [] // No path found
    }
    
    private func calculateEdgeWeight(from: GridPosition, to: GridPosition) -> Float {
        let baseCost: Float = 1.0
        let crowdLevel = Float(crowdData.getCrowdLevel(at: to))
        
        // Add debug logging
        if crowdLevel > 0 {
            print("🚶‍♂️ Position (\(to.x), \(to.y)) has crowd level: \(crowdLevel)")
        }
        
        // Scale crowd penalty - adjust these values as needed
        let crowdPenalty: Float
        switch Int(crowdLevel) {
        case 0...5: crowdPenalty = 0.0      // No penalty for low crowd
        case 6...10: crowdPenalty = 2.0     // Medium penalty
        case 11...15: crowdPenalty = 5.0    // High penalty
        case 16...20: crowdPenalty = 10.0   // Very high penalty
        default: crowdPenalty = 15.0        // Extreme penalty
        }
        
        let totalWeight = baseCost + crowdPenalty
        
        // Add debug logging for weights
        if crowdPenalty > 0 {
            print("📊 Edge weight from (\(from.x), \(from.y)) to (\(to.x), \(to.y)): \(totalWeight) (base: \(baseCost), penalty: \(crowdPenalty))")
        }
        
        return totalWeight
    }
    
    private func getWalkableNeighbors(of position: GridPosition) -> [GridPosition] {
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)] // up, right, down, left
        var neighbors: [GridPosition] = []
        
        for (dx, dy) in directions {
            let neighbor = GridPosition(x: position.x + dx, y: position.y + dy)
            
            // Check if position is walkable using existing GameplayKit graph
            if let _ = gridGraph.node(atGridPosition: vector_int2(Int32(neighbor.x), Int32(neighbor.y))) {
                neighbors.append(neighbor)
            }
        }
        
        return neighbors
    }
    
    private func heuristic(_ a: GridPosition, _ b: GridPosition) -> Float {
        // Manhattan distance
        return Float(abs(a.x - b.x) + abs(a.y - b.y))
    }
    
    private func reconstructPath(cameFrom: [GridPosition: GridPosition], current: GridPosition) -> [GridPosition] {
        var path = [current]
        var current = current
        
        while let previous = cameFrom[current] {
            path.insert(previous, at: 0)
            current = previous
        }
        
        return path
    }
    
    // Add this function to analyze the path
    func analyzePath() -> String {
        guard !currentPath.isEmpty else { return "No path calculated" }
        
        var analysis = "🛤️ Path Analysis:\n"
        var totalCrowdExposure = 0
        
        for (index, node) in currentPath.enumerated() {
            let position = GridPosition(x: Int(node.gridPosition.x), y: Int(node.gridPosition.y))
            let crowdLevel = crowdData.getCrowdLevel(at: position)
            totalCrowdExposure += crowdLevel
            
            analysis += "Step \(index + 1): (\(position.x), \(position.y)) - Crowd: \(crowdLevel)\n"
        }
        
        analysis += "Total crowd exposure: \(totalCrowdExposure)\n"
        analysis += "Average crowd per step: \(Double(totalCrowdExposure) / Double(currentPath.count))"
        
        return analysis
    }
}
