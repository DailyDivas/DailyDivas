// Commit Test; Please Ignore

import Foundation
import SwiftUI

enum Hall: String, CaseIterable {
    case hallA = "Hall A"
    case hallB = "Hall B" 
    case hallC = "Hall C"
}

struct GridPosition: Hashable, Equatable {
    let x: Int
    let y: Int
}

// Basic structure for future booth implementation
struct Booth: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let gridPosition: GridPosition
    let hall: Hall
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
