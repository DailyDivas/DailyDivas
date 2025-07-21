import Foundation
import GameplayKit

class EventMapPathfinding: NSObject {
    private var gridGraph: GKGridGraph<GKGridGraphNode>
    private let gridWidth: Int32
    private let gridHeight: Int32
    private var booths: [Booth] = []
    private var crowdData: CrowdData
    
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
        setupInitialBooths()
    }
    
    private func setupInitialBooths() {
        // Empty for now - will add booths later
        booths = []
    }
    
    func getBooths(for hall: Hall? = nil) -> [Booth] {
        if let hall = hall {
            return booths.filter { $0.hall == hall }
        }
        return booths
    }
    
    func getHallConfig(for hall: Hall) -> HallConfig? {
        return hallConfigs.first { $0.hall == hall }
    }
    
    func getAllHallConfigs() -> [HallConfig] {
        return hallConfigs
    }
}
