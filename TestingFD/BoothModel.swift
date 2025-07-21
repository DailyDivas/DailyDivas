// Commit Test; Please Ignore

import Foundation
import SwiftUI

struct Booth: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let gridPosition: GridPosition
    let size: BoothSize
    let hasBeacon: Bool
    
    enum BoothSize {
        case small // 1x1
        case large // 2x2
    }
}

struct GridPosition: Hashable, Equatable {
    let x: Int
    let y: Int
}

class CrowdData: ObservableObject {
    @Published var crowdLevels: [GridPosition: Float] = [:]
    
    func updateCrowdLevel(at position: GridPosition, level: Float) {
        crowdLevels[position] = level
    }
    
    func getCrowdLevel(at position: GridPosition) -> Float {
        return crowdLevels[position] ?? 0.0
    }
}
