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

// Basic structure for booth implementation (no crowd data)
struct Booth: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let gridPosition: GridPosition
    let hall: Hall
    var isActive: Bool = true
    var beaconUUID: String = UUID().uuidString
    var categories: [BoothCategory] = []
}

// CCTV structure for monitoring pathways
struct CCTV: Identifiable {
    let id = UUID()
    let name: String
    let position: GridPosition
    let hall: Hall
    let monitoredPathway: [GridPosition] // Vertical pathway positions this CCTV monitors
    var peopleCount: Int = 0
    var lastUpdated: Date = Date()
}

class CrowdData: ObservableObject {
    @Published var booths: [Booth] = []
    @Published var cctvs: [CCTV] = []
    @Published var pathwayCrowdLevels: [Int: Int] = [:] // CCTV ID -> People Count
    
    init() {
        setupInitialBooths()
        setupCCTVs()
        startCCTVSimulation()
    }
    
    func getBooths(for hall: Hall? = nil) -> [Booth] {
        if let hall = hall {
            return booths.filter { $0.hall == hall }
        }
        return booths
    }
    
    // Get crowd level for a specific pathway position
    func getCrowdLevel(at position: GridPosition) -> Int {
        // Find which CCTV monitors this position
        for cctv in cctvs {
            if cctv.monitoredPathway.contains(position) {
                return pathwayCrowdLevels[cctv.id.hashValue] ?? 0
            }
        }
        return 0
    }
    
    // Get CCTV monitoring a specific position
    func getCCTV(monitoring position: GridPosition) -> CCTV? {
        return cctvs.first { $0.monitoredPathway.contains(position) }
    }
    
    private func setupInitialBooths() {
        var newBooths: [Booth] = []
        
        // Hall C booths (y: 0-7, 9 wide, centered)
        let hallCStartX = (12 - 9) / 2
        
        // First column - 1x1 booths (leftmost column of Hall C)
        for y in 0...7 {
            var booth = Booth(
                name: "C\(y + 1)-1x1",
                gridPosition: GridPosition(x: hallCStartX, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Columns 2-3: 2x2 booths
        for y in stride(from: 0, through: 6, by: 2) {
            var booth = Booth(
                name: "C\((y/2) + 1)-2x2",
                gridPosition: GridPosition(x: hallCStartX + 2, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Columns 5-6: 2x2 booths
        for y in stride(from: 0, through: 6, by: 2) {
            var booth = Booth(
                name: "C\((y/2) + 5)-2x2",
                gridPosition: GridPosition(x: hallCStartX + 5, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Last column - 1x1 booths (rightmost column of Hall C)
        for y in 0...7 {
            var booth = Booth(
                name: "C\(y + 9)-1x1",
                gridPosition: GridPosition(x: hallCStartX + 8, y: y),
                hall: .hallC
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Hall B booths (y: 9-14, 12 wide, full width)
        for y in 9...14 {
            var booth = Booth(
                name: "B\(y - 8)-1x1",
                gridPosition: GridPosition(x: 0, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in stride(from: 9, through: 13, by: 2) {
            var booth = Booth(
                name: "B\((y - 9)/2 + 7)-2x2",
                gridPosition: GridPosition(x: 2, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in stride(from: 9, through: 13, by: 2) {
            var booth = Booth(
                name: "B\((y - 9)/2 + 10)-2x2",
                gridPosition: GridPosition(x: 5, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in 9...14 {
            var booth = Booth(
                name: "B\(y - 8 + 6)-1x1",
                gridPosition: GridPosition(x: 8, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in 9...14 {
            var booth = Booth(
                name: "B\(y - 8 + 12)-1x1",
                gridPosition: GridPosition(x: 10, y: y),
                hall: .hallB
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Hall A booths (y: 16-21, 10 wide, centered)
        let hallAStartX = (12 - 10) / 2
        
        for y in 16...21 {
            var booth = Booth(
                name: "A\(y - 15)-1x1",
                gridPosition: GridPosition(x: hallAStartX, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in stride(from: 16, through: 20, by: 2) {
            var booth = Booth(
                name: "A\((y - 16)/2 + 7)-2x2",
                gridPosition: GridPosition(x: hallAStartX + 2, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in stride(from: 16, through: 20, by: 2) {
            var booth = Booth(
                name: "A\((y - 16)/2 + 10)-2x2",
                gridPosition: GridPosition(x: hallAStartX + 5, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        for y in 16...21 {
            var booth = Booth(
                name: "A\(y - 15 + 6)-1x1",
                gridPosition: GridPosition(x: hallAStartX + 8, y: y),
                hall: .hallA
            )
            booth.categories = generateRandomCategories()
            newBooths.append(booth)
        }
        
        // Randomly select 4 booths to rename with custom names
        let customNames = ["Niveo", "Vaselon", "Erho", "Skintipis"]
        let selectedIndices = Array(0..<newBooths.count).shuffled().prefix(4)
        
        for (index, boothIndex) in selectedIndices.enumerated() {
            let originalSize = newBooths[boothIndex].name.contains("2x2") ? "2x2" : "1x1"
            newBooths[boothIndex] = Booth(
                name: "\(customNames[index])-\(originalSize)",
                gridPosition: newBooths[boothIndex].gridPosition,
                hall: newBooths[boothIndex].hall,
                isActive: newBooths[boothIndex].isActive,
                beaconUUID: newBooths[boothIndex].beaconUUID,
                categories: newBooths[boothIndex].categories
            )
        }
        
        self.booths = newBooths
    }
    
    private func setupCCTVs() {
        var newCCTVs: [CCTV] = []
        
        // Hall C CCTVs - monitoring vertical pathways
        // Place CCTVs at the top corners of each pathway
        let hallCStartX = (12 - 9) / 2
        
        // CCTV for pathway at x = hallCStartX + 1 (between first column and 2x2 booths)
        var pathway1: [GridPosition] = []
        for y in 0...7 {
            pathway1.append(GridPosition(x: hallCStartX + 1, y: y))
        }
        newCCTVs.append(CCTV(
            name: "CCTV-C1",
            position: GridPosition(x: hallCStartX + 1, y: 0), // Top corner of pathway
            hall: .hallC,
            monitoredPathway: pathway1
        ))
        
        // CCTV for pathway at x = hallCStartX + 4 (between 2x2 booth columns)
        var pathway2: [GridPosition] = []
        for y in 0...7 {
            pathway2.append(GridPosition(x: hallCStartX + 4, y: y))
        }
        newCCTVs.append(CCTV(
            name: "CCTV-C2",
            position: GridPosition(x: hallCStartX + 4, y: 0), // Top corner of pathway
            hall: .hallC,
            monitoredPathway: pathway2
        ))
        
        // CCTV for pathway at x = hallCStartX + 7 (between 2x2 booths and last column)
        var pathway3: [GridPosition] = []
        for y in 0...7 {
            pathway3.append(GridPosition(x: hallCStartX + 7, y: y))
        }
        newCCTVs.append(CCTV(
            name: "CCTV-C3",
            position: GridPosition(x: hallCStartX + 7, y: 0), // Top corner of pathway
            hall: .hallC,
            monitoredPathway: pathway3
        ))
        
        // Hall B CCTVs - monitoring vertical pathways (x = 1, 4, 7, 9, 11)
        // Place CCTVs at the top corners of each pathway
        let pathwayPositionsB = [1, 4, 7, 9, 11] // Added 11 for the rightmost pathway
        for (index, x) in pathwayPositionsB.enumerated() {
            var pathway: [GridPosition] = []
            for y in 9...14 {
                pathway.append(GridPosition(x: x, y: y))
            }
            newCCTVs.append(CCTV(
                name: "CCTV-B\(index + 1)",
                position: GridPosition(x: x, y: 9), // Top corner of Hall B pathway
                hall: .hallB,
                monitoredPathway: pathway
            ))
        }
        
        // Hall A CCTVs - monitoring vertical pathways
        // Place CCTVs at the top corners of each pathway
        let hallAStartX = (12 - 10) / 2
        let pathwayPositionsA = [hallAStartX + 1, hallAStartX + 4, hallAStartX + 7, hallAStartX + 9] // Added hallAStartX + 9 for the rightmost pathway

        for (index, x) in pathwayPositionsA.enumerated() {
            var pathway: [GridPosition] = []
            for y in 16...21 {
                pathway.append(GridPosition(x: x, y: y))
            }
            newCCTVs.append(CCTV(
                name: "CCTV-A\(index + 1)",
                position: GridPosition(x: x, y: 16), // Top corner of Hall A pathway
                hall: .hallA,
                monitoredPathway: pathway
            ))
        }
        
        self.cctvs = newCCTVs
        
        // Initialize crowd levels for all CCTVs
        for cctv in cctvs {
            pathwayCrowdLevels[cctv.id.hashValue] = Int.random(in: 0...15)
        }
    }
    
    private func startCCTVSimulation() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateCCTVData()
            }
        }
    }
    
    private func updateCCTVData() {
        for cctv in cctvs {
            // Simulate ML model counting people (0-20 people per pathway)
            let newCount = Int.random(in: 0...20)
            pathwayCrowdLevels[cctv.id.hashValue] = newCount
            
            // Update the CCTV's last updated time
            if let index = cctvs.firstIndex(where: { $0.id == cctv.id }) {
                cctvs[index].peopleCount = newCount
                cctvs[index].lastUpdated = Date()
            }
        }
    }
    
    // Helper function to generate random categories
    private func generateRandomCategories() -> [BoothCategory] {
        let allCategories = BoothCategory.allCases
        let numberOfCategories = Int.random(in: 1...2)
        
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
    
    // Helper function to get booths by category
    func getBooths(for category: BoothCategory) -> [Booth] {
        return booths.filter { $0.categories.contains(category) }
    }
    
    // Helper function to get booths by multiple categories
    func getBooths(for categories: [BoothCategory]) -> [Booth] {
        return booths.filter { booth in
            return categories.allSatisfy { category in
                booth.categories.contains(category)
            }
        }
    }
    
    // Function to update people count from ML model (to be called externally)
    func updatePeopleCount(for cctvId: UUID, count: Int) {
        pathwayCrowdLevels[cctvId.hashValue] = count
        
        if let index = cctvs.firstIndex(where: { $0.id == cctvId }) {
            cctvs[index].peopleCount = count
            cctvs[index].lastUpdated = Date()
        }
    }
}
