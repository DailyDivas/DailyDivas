// Commit Test; Please Ignore

import Foundation
import SwiftUI

enum Hall: String, CaseIterable {
    case hallA = "Hall A"
    case hallB = "Hall B" 
    case hallC = "Hall C"
}

enum BoothCategory: String, CaseIterable {
    case bodycare = "bodycare"
    case haircare = "haircare"
    case lipcare = "lipcare"
    case makeup = "makeup"
    case perfume = "perfume"
    case skincare = "skincare"
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
    var crowdLevel: Float = 0.0
    var isActive: Bool = true
    var beaconUUID: String = UUID().uuidString
    var categories: [BoothCategory] = []
}

class CrowdData: ObservableObject {
    @Published var crowdLevels: [GridPosition: Float] = [:]
    @Published var booths: [Booth] = []
    
    init() {
        setupInitialBooths()
        startCrowdSimulation()
    }
    
    func updateCrowdLevel(at position: GridPosition, level: Float) {
        crowdLevels[position] = level
        
        // Update booth crowd level if there's a booth at this position
        if let index = booths.firstIndex(where: { $0.gridPosition == position }) {
            booths[index].crowdLevel = level
        }
    }
    
    func getCrowdLevel(at position: GridPosition) -> Float {
        return crowdLevels[position] ?? 0.0
    }
    
    func getBooths(for hall: Hall? = nil) -> [Booth] {
        if let hall = hall {
            return booths.filter { $0.hall == hall }
        }
        return booths
    }
    
    private func setupInitialBooths() {
        var newBooths: [Booth] = []
        
        // Hall C booths (y: 0-7, 9 wide, centered)
        // Calculate the left padding to center Hall C in the 12-wide grid
        let hallCStartX = (12 - 9) / 2 // This gives us 1.5, rounded down to 1
        
        // First column - 1x1 booths (leftmost column of Hall C) - full vertical span
        for y in 0...7 {
            var booth = Booth(
                name: "C-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallCStartX, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Columns 2-3: 2x2 booths (positioned at their top-left corner) - full vertical span
        for y in stride(from: 0, through: 6, by: 2) {
            var booth = Booth(
                name: "C-2x2-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallCStartX + 2, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Columns 5-6: 2x2 booths (positioned at their top-left corner) - full vertical span
        for y in stride(from: 0, through: 6, by: 2) {
            var booth = Booth(
                name: "C-2x2-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallCStartX + 5, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Last column - 1x1 booths (rightmost column of Hall C) - full vertical span
        for y in 0...7 {
            var booth = Booth(
                name: "C-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallCStartX + 8, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Hall B booths (y: 8-15, 12 wide, full width)
        // Column 0: 1x1 booths (leftmost)
        for y in 9...14 {
            var booth = Booth(
                name: "B-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: 0, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 1: Path (no booths)
        
        // Columns 2-3: 2x2 booths
        for y in stride(from: 9, through: 13, by: 2) {
            var booth = Booth(
                name: "B-2x2-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: 2, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 4: Path (no booths)
        
        // Columns 5-6: 2x2 booths
        for y in stride(from: 9, through: 13, by: 2) {
            var booth = Booth(
                name: "B-2x2-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: 5, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 7: Path (no booths)
        
        // Column 8: 1x1 booths
        for y in 9...14 {
            var booth = Booth(
                name: "B-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: 8, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 9: Path (no booths)
        
        // Column 10: 1x1 booths
        for y in 9...14 {
            var booth = Booth(
                name: "B-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: 10, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Hall A booths (y: 16-21, 10 wide, centered)
        // Sequence: 1x1 booth, path, 2x2 booth, path, 2x2 booth, path, 1x1 booth
        // Use full vertical span (y: 16-21, so 6 rows available)
        let hallAStartX = (12 - 10) / 2 // This gives us 1
        
        // Column 0: 1x1 booths (leftmost) - full vertical span
        for y in 16...21 {
            var booth = Booth(
                name: "A-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallAStartX, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 1: Path (no booths)
        
        // Columns 2-3: 2x2 booths - full vertical span
        for y in stride(from: 16, through: 20, by: 2) {
            var booth = Booth(
                name: "A-2x2-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallAStartX + 2, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 4: Path (no booths)
        
        // Columns 5-6: 2x2 booths - full vertical span
        for y in stride(from: 16, through: 20, by: 2) {
            var booth = Booth(
                name: "A-2x2-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallAStartX + 5, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Column 7: Path (no booths)
        
        // Column 8: 1x1 booths (rightmost) - full vertical span
        for y in 16...21 {
            var booth = Booth(
                name: "A-1x1-\(newBooths.count + 1)",
                gridPosition: GridPosition(x: hallAStartX + 8, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Store all booths (Hall C + Hall B + Hall A)
        self.booths = newBooths
        
        // Initialize crowd levels for all booth positions
        for booth in booths {
            crowdLevels[booth.gridPosition] = Float.random(in: 0.2...0.8)
        }
    }
    
    private func startCrowdSimulation() {
        Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateCrowdSimulation()
            }
        }
    }
    
    private func updateCrowdSimulation() {
        for booth in booths {
            // Simulate crowd level changes
            let currentLevel = crowdLevels[booth.gridPosition] ?? 0.0
            let change = Float.random(in: -0.2...0.2)
            let newLevel = max(0.0, min(1.0, currentLevel + change))
            
            updateCrowdLevel(at: booth.gridPosition, level: newLevel)
        }
    }
    
    // Add this helper function to generate random categories
    private func generateRandomCategories() -> [BoothCategory] {
        let allCategories = BoothCategory.allCases
        let numberOfCategories = Int.random(in: 1...2) // 1 or 2 categories
        
        var selectedCategories: [BoothCategory] = []
        
        for _ in 0..<numberOfCategories {
            var randomCategory: BoothCategory
            repeat {
                randomCategory = allCategories.randomElement()!
            } while selectedCategories.contains(randomCategory)
            
            selectedCategories.append(randomCategory)
        }
        
        return selectedCategories
    }
    
    // Add helper function to get booths by category
    func getBooths(for category: BoothCategory) -> [Booth] {
        return booths.filter { $0.categories.contains(category) }
    }
    
    // Add helper function to get booths by multiple categories
    func getBooths(for categories: [BoothCategory]) -> [Booth] {
        return booths.filter { booth in
            return categories.allSatisfy { category in
                booth.categories.contains(category)
            }
        }
    }
}
