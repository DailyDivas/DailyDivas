import SwiftUI
import simd

// MARK: - Missing ZoomSection enum
enum ZoomSection: CaseIterable {
    case none
    case hallA
    case hallB
    case hallC
    
    var title: String {
        switch self {
        case .none: return "All Halls"
        case .hallA: return "Hall A"
        case .hallB: return "Hall B"
        case .hallC: return "Hall C"
        }
    }
}

// MARK: - Separated Visual Components

struct MapGridComponent: View {
    let pathfinding: EventMapPathfinding
    let gridSize: CGFloat
    let totalMapWidth: Int
    let totalMapHeight: Int
    let zoomedSection: ZoomSection
    
    var body: some View {
        ZStack {
            ForEach(pathfinding.getAllHallConfigs(), id: \.hall) { config in
                hallGrid(config: config)
            }
        }
    }
    
    private func hallGrid(config: EventMapPathfinding.HallConfig) -> some View {
        VStack(spacing: 0) {
            ForEach(config.yStart...config.yEnd, id: \.self) { y in
                HStack(spacing: 0) {
                    ForEach(0..<totalMapWidth, id: \.self) { x in
                        Rectangle()
                            .fill(isValidHallPosition(x: x, y: y, config: config) ? 
                                  hallBackgroundColor(for: config.hall) : Color.clear)
                            .frame(width: gridSize, height: gridSize)
                            .border(isValidHallPosition(x: x, y: y, config: config) ? 
                                   Color.gray.opacity(0.3) : Color.clear, width: 0.5)
                            .opacity(hallOpacity(for: config.hall))
                    }
                }
            }
        }
        .position(x: CGFloat(totalMapWidth) * gridSize / 2,
                  y: CGFloat(config.yStart + config.yEnd) * gridSize / 2)
    }
    
    private func isValidHallPosition(x: Int, y: Int, config: EventMapPathfinding.HallConfig) -> Bool {
        let leftPadding = (totalMapWidth - config.width) / 2
        let rightBound = leftPadding + config.width
        return x >= leftPadding && x < rightBound && y >= config.yStart && y <= config.yEnd
    }
    
    private func hallBackgroundColor(for hall: Hall) -> Color {
        switch hall {
        case .hallC: return Color.orange.opacity(0.1)
        case .hallB: return Color.green.opacity(0.1)
        case .hallA: return Color.blue.opacity(0.1)
        }
    }
    
    private func hallOpacity(for hall: Hall) -> Double {
        switch zoomedSection {
        case .none: return 1.0
        case .hallA: return hall == .hallA ? 1.0 : 0.3
        case .hallB: return hall == .hallB ? 1.0 : 0.3
        case .hallC: return hall == .hallC ? 1.0 : 0.3
        }
    }
}

struct PathVisualizationComponent: View {
    let pathfinding: EventMapPathfinding
    let gridSize: CGFloat
    let completedPathIndices: Set<Int>
    let isNavigationActive: Bool // Add this parameter
    let onCheckpointTap: (Int) -> Void
    
    var body: some View {
        ZStack {
            // Path lines
            pathLines
            
            // Checkpoints - only show when navigation is active
            if isNavigationActive {
                pathCheckpoints
            }
        }
    }
    
    private var pathLines: some View {
        ZStack {
            ForEach(0..<max(0, pathfinding.currentPath.count - 1), id: \.self) { index in
                let startNode = pathfinding.currentPath[index]
                let endNode = pathfinding.currentPath[index + 1]
                
                let isCompleted = isNavigationActive && completedPathIndices.contains(index)
                let lineColor = isCompleted ? Color.gray : Color.blue
                
                let startPos = CGPoint(
                    x: CGFloat(startNode.gridPosition.x) * gridSize + gridSize/2,
                    y: CGFloat(startNode.gridPosition.y) * gridSize
                )
                let endPos = CGPoint(
                    x: CGFloat(endNode.gridPosition.x) * gridSize + gridSize/2,
                    y: CGFloat(endNode.gridPosition.y) * gridSize
                )
                
                Path { path in
                    path.move(to: startPos)
                    path.addLine(to: endPos)
                }
                .stroke(lineColor, lineWidth: 3)
                .opacity(0.8)
            }
        }
        .allowsHitTesting(false)
    }
    
    private var pathCheckpoints: some View {
        ForEach(Array(getDirectionChangeIndices().enumerated()), id: \.offset) { arrayIndex, pathIndex in
            let node = pathfinding.currentPath[pathIndex]
            let isCompleted = completedPathIndices.contains(pathIndex)
            let isLastCheckpoint = pathIndex == pathfinding.currentPath.count - 1
            let fillColor = isCompleted ? Color.gray : (isLastCheckpoint ? Color.red : Color.blue)
            
            let xPos = CGFloat(node.gridPosition.x) * gridSize + gridSize/2
            let yPos = CGFloat(node.gridPosition.y) * gridSize
            
            Circle()
                .fill(fillColor)
                .frame(width: 16, height: 16)
                .position(x: xPos, y: yPos)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .position(x: xPos, y: yPos)
                )
                .onTapGesture {
                    onCheckpointTap(pathIndex)
                }
        }
    }
    
    private func getDirectionChangeIndices() -> [Int] {
        guard pathfinding.currentPath.count > 2 else {
            return Array(0..<pathfinding.currentPath.count)
        }
        
        var indices: [Int] = []
        indices.append(0)
        
        for i in 1..<pathfinding.currentPath.count - 1 {
            let prevNode = pathfinding.currentPath[i - 1]
            let currentNode = pathfinding.currentPath[i]
            let nextNode = pathfinding.currentPath[i + 1]
            
            let directionToCurrent = (
                x: currentNode.gridPosition.x - prevNode.gridPosition.x,
                y: currentNode.gridPosition.y - prevNode.gridPosition.y
            )
            
            let directionFromCurrent = (
                x: nextNode.gridPosition.x - currentNode.gridPosition.x,
                y: nextNode.gridPosition.y - currentNode.gridPosition.y
            )
            
            if directionToCurrent.x != directionFromCurrent.x || directionToCurrent.y != directionFromCurrent.y {
                indices.append(i)
            }
        }
        
        indices.append(pathfinding.currentPath.count - 1)
        return indices
    }
}

struct BoothsOverlayComponent: View {
    let booths: [Booth]
    let gridSize: CGFloat
    let totalMapWidth: Int
    let totalMapHeight: Int
    let selectedCategory: BoothCategory?
    let selectedBoothForDestination: Booth?
    let zoomedSection: ZoomSection
    let isNavigationActive: Bool
    let isSelectingStartPoint: Bool
    let pathfinding: EventMapPathfinding // Add this parameter to check start/end points
    let onBoothTap: (Booth) -> Void
    
    var body: some View {
        ZStack {
            ForEach(booths) { booth in
                if shouldShowHall(booth.hall) {
                    BoothView(
                        booth: booth,
                        gridSize: gridSize,
                        selectedCategory: selectedCategory,
                        isSelectedForDestination: selectedBoothForDestination?.id == booth.id,
                        zoomedSection: zoomedSection,
                        isNavigationActive: isNavigationActive,
                        onTap: { 
                            // Allow booth tapping when:
                            // 1. Navigation is not active AND
                            // 2. We're selecting start point OR we have start point but no destination
                            if !isNavigationActive && (isSelectingStartPoint || (pathfinding.startPoint != nil && pathfinding.endPoint == nil)) {
                                onBoothTap(booth)
                            } else if !isNavigationActive {
                                onBoothTap(booth)
                            }
                        }
                    )
                    .position(
                        x: CGFloat(booth.gridPosition.x) * gridSize + (booth.name.contains("2x2") ? gridSize : gridSize/2),
                        y: CGFloat(booth.gridPosition.y) * gridSize + (booth.name.contains("2x2") ? gridSize : gridSize/2) - gridSize/2
                    )
                }
            }
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    private func shouldShowHall(_ hall: Hall) -> Bool {
        return true
    }
}

struct BoothView: View {
    let booth: Booth
    let gridSize: CGFloat
    let selectedCategory: BoothCategory?
    let isSelectedForDestination: Bool
    let zoomedSection: ZoomSection
    let isNavigationActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        let is2x2Booth = booth.name.contains("2x2")
        let boothSize = is2x2Booth ? gridSize * 2 : gridSize
        let isHighlighted = selectedCategory != nil && booth.categories.contains(selectedCategory!)
        
        Rectangle()
            .fill(boothColor(for: booth))
            .frame(width: boothSize, height: boothSize)
            .border(
                isSelectedForDestination ? Color.red : 
                (isHighlighted ? Color.yellow : boothBorderColor(for: booth)), 
                width: isSelectedForDestination ? 3 : (isHighlighted ? 3 : 1)
            )
            .opacity(boothOpacity(for: booth))
            .overlay(
                ZStack {
                    // Category indicators at the top
                    if !booth.categories.isEmpty && boothSize >= gridSize {
                        VStack {
                            HStack(spacing: 2) {
                                ForEach(booth.categories.prefix(2), id: \.self) { category in
                                    Circle()
                                        .fill(categoryColor(for: category))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.top, 2)
                            
                            Spacer()
                        }
                    }
                    
                    // Booth name at the bottom (only when selected for destination)
                    if isSelectedForDestination && boothSize >= gridSize {
                        VStack {
                            Spacer()
                            
                            Text(booth.name)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(2)
                                .padding(.bottom, 2)
                        }
                    }
                    
                    // Disabled overlay when navigation is active - should cover the entire booth
                    if isNavigationActive {
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: boothSize, height: boothSize)
                    }
                }
            )
            .onTapGesture {
                onTap()
            }
    }
    
    private func boothColor(for booth: Booth) -> Color {
        switch booth.hall {
        case .hallA: return Color.blue.opacity(0.7)
        case .hallB: return Color.green.opacity(0.7)
        case .hallC: return Color.orange.opacity(0.7)
        }
    }
    
    private func boothBorderColor(for booth: Booth) -> Color {
        switch booth.hall {
        case .hallA: return Color.blue
        case .hallB: return Color.green
        case .hallC: return Color.orange
        }
    }
    
    private func boothOpacity(for booth: Booth) -> Double {
        let baseOpacity = hallOpacity(for: booth.hall)
        
        // Don't modify opacity during navigation since we're using an overlay instead
        if let selectedCategory = selectedCategory {
            let matchesFilter = booth.categories.contains(selectedCategory)
            return matchesFilter ? baseOpacity : baseOpacity * 0.3
        } else {
            return baseOpacity
        }
    }
    
    private func hallOpacity(for hall: Hall) -> Double {
        switch zoomedSection {
        case .none: return 1.0
        case .hallA: return hall == .hallA ? 1.0 : 0.3
        case .hallB: return hall == .hallB ? 1.0 : 0.3
        case .hallC: return hall == .hallC ? 1.0 : 0.3
        }
    }
    
    private func categoryColor(for category: BoothCategory) -> Color {
        switch category {
        case .bodycare: return .purple
        case .haircare: return .brown
        case .lipcare: return .pink
        case .makeup: return .red
        case .perfume: return .mint
        case .skincare: return .cyan
        }
    }
}

struct CCTVOverlayComponent: View {
    let cctvs: [CCTV]
    let gridSize: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(cctvs) { cctv in
                VStack(spacing: 2) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                    
                    Text("\(cctv.peopleCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(crowdColorForCount(cctv.peopleCount))
                        .cornerRadius(4)
                }
                .position(
                    x: CGFloat(cctv.position.x) * gridSize + gridSize/2,
                    y: CGFloat(cctv.position.y) * gridSize
                )
            }
            
            PathwayCrowdVisualization(cctvs: cctvs, gridSize: gridSize)
        }
        .allowsHitTesting(false)
    }
    
    private func crowdColorForCount(_ count: Int) -> Color {
        switch count {
        case 0...5: return .green
        case 6...10: return .yellow
        case 11...15: return .orange
        default: return .red
        }
    }
}

struct PathwayCrowdVisualization: View {
    let cctvs: [CCTV]
    let gridSize: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(cctvs) { cctv in
                ForEach(cctv.monitoredPathway, id: \.self) { position in
                    Rectangle()
                        .fill(crowdColorForCount(cctv.peopleCount).opacity(0.3))
                        .frame(width: gridSize, height: gridSize)
                        .position(
                            x: CGFloat(position.x) * gridSize + gridSize/2,
                            y: CGFloat(position.y) * gridSize
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func crowdColorForCount(_ count: Int) -> Color {
        switch count {
        case 0...5: return .green
        case 6...10: return .yellow
        case 11...15: return .orange
        default: return .red
        }
    }
}

struct StartPointOverlayComponent: View {
    let allWalkablePositions: [GridPosition]
    let gridSize: CGFloat
    let showStartPoints: Bool
    let onStartPointTap: (GridPosition) -> Void
    
    var body: some View {
        ZStack {
            if showStartPoints {
                ForEach(allWalkablePositions, id: \.self) { position in
                    let xPosition = CGFloat(position.x) * gridSize + gridSize/2
                    let yPosition = CGFloat(position.y) * gridSize
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .position(x: xPosition, y: yPosition)
                        .opacity(0.7)
                        .onTapGesture {
                            onStartPointTap(position)
                        }
                }
            }
        }
    }
}

struct PathfindingMarkersComponent: View {
    let startPoint: GridPosition?
    let endPoint: GridPosition?
    let gridSize: CGFloat
    
    var body: some View {
        ZStack {
            if let startPoint = startPoint {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .position(
                        x: CGFloat(startPoint.x) * gridSize + gridSize/2,
                        y: CGFloat(startPoint.y) * gridSize
                    )
            }
            
            if let endPoint = endPoint {
                Image(systemName: "flag.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .position(
                        x: CGFloat(endPoint.x) * gridSize + gridSize/2,
                        y: CGFloat(endPoint.y) * gridSize
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

struct HallLabelsComponent: View {
    let hallConfigs: [EventMapPathfinding.HallConfig]
    let gridSize: CGFloat
    let totalMapWidth: Int
    let shouldShowHall: (Hall) -> Bool
    
    var body: some View {
        ZStack {
            ForEach(hallConfigs, id: \.hall) { config in
                if shouldShowHall(config.hall) {
                    Text(config.hall.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                        .position(x: CGFloat(totalMapWidth) * gridSize / 2,
                                  y: CGFloat(config.yStart + 1) * gridSize)
                }
            }
        }
        .allowsHitTesting(false) // Add this line to prevent blocking touch events
    }
}

// MARK: - Main EventMapView (Cleaned up)

struct EventMapView: View {
    @StateObject private var crowdData = CrowdData()
    @StateObject private var pathfinding: EventMapPathfinding
    
    init() {
        let crowdData = CrowdData()
        self._crowdData = StateObject(wrappedValue: crowdData)
        self._pathfinding = StateObject(wrappedValue: EventMapPathfinding(width: 12, height: 22, crowdData: crowdData))
    }
    
    @State private var zoomedSection: ZoomSection = .none
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedCategory: BoothCategory? = nil
    @State private var showCategoryFilter = false
    @State private var selectedBoothForDestination: Booth? = nil
    @State private var showBoothDetails = false
    @State private var completedPathIndices: Set<Int> = []
    @State private var showMapOptions = false
    @State private var showCrowdInfo = false
    @State private var showBoothList = false
    @State private var showRouteSelector = false
    @State private var routeSelectorMode: RouteSelectorMode = .destination
    @State private var isNavigationActive = false // Add this new state
    @State private var isSelectingStartPoint = false // Add this state

    // Add enum for route selector modes
    enum RouteSelectorMode {
        case start
        case destination
    }

    private let gridSize: CGFloat = 40
    private let totalMapWidth: Int = 12
    private let totalMapHeight: Int = 22
    
    var body: some View {
        ZStack {
            mapContent
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .gesture(mapGestures)
            
            VStack {
                // Only show route selector when navigation is not active
                if !isNavigationActive {
                    routeSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
                
                if showBoothDetails, let selectedBooth = selectedBoothForDestination {
                    boothDetailsPanel(for: selectedBooth)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                }
                
                if pathfinding.endPoint != nil || pathfinding.startPoint != nil {
                    pathfindingInstructions
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 4)
                }
                
                if showCategoryFilter {
                    categoryFilterPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Updated navigation buttons - only show crowd info when navigation is not active
            VStack {
                Spacer()
                HStack {
                    // Only show crowd info button when navigation is not active
                    if !isNavigationActive {
                        crowdInfoButton
                    }
                    
                    // Add start navigation button when both points are set
                    if pathfinding.startPoint != nil && pathfinding.endPoint != nil && !isNavigationActive {
                        startNavigationButton
                    }
                    
                    Spacer()
                    mapNavigationButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 56)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showBoothList) {
            BoothListSheet(
                booths: crowdData.getBooths(),
                mode: routeSelectorMode,
                onBoothSelected: { booth in
                    showBoothList = false
                    handleRouteSelection(booth)
                }
            )
            .presentationDragIndicator(.visible) // Move this here, outside the sheet content
        }
    }
    
    // Add the new start navigation button
    private var startNavigationButton: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                isNavigationActive = true
            }
        }) {
            Text("Start Navigation")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color(red: 0.859, green: 0.157, blue: 0.306))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .padding(.leading, 24)
    }
    
    // Update the route selector component
    private var routeSelector: some View {
        VStack(spacing: 0) {
            // Starting point field
            HStack(spacing: 12) {
                Circle()
                    .stroke(Color(red: 0.859, green: 0.157, blue: 0.306), lineWidth: 2)
                    .fill(Color.clear)
                    .frame(width: 12, height: 12)
                
                Button(action: {
                    routeSelectorMode = .start
                    isSelectingStartPoint = true
                    showBoothList = true
                }) {
                    HStack {
                        Text(startPointText)
                            .font(.system(size: 16))
                            .foregroundColor(startPointColor)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
                .padding(.vertical, 12)
            
            // Destination field
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundColor(Color(red: 0.859, green: 0.157, blue: 0.306))
                    .frame(width: 12, height: 12)
                
                Button(action: {
                    routeSelectorMode = .destination
                    isSelectingStartPoint = false
                    showBoothList = true
                }) {
                    HStack {
                        Text(destinationText)
                            .font(.system(size: 16))
                            .foregroundColor(destinationColor)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 48)
        .padding(.horizontal, 56)
    }
    
    // Helper computed properties for route selector text and colors
    private var startPointText: String {
        if let startPoint = pathfinding.startPoint {
            return "Starting from (\(startPoint.x), \(startPoint.y))"
        } else {
            return "Tulis Brand di Sekitarmu"
        }
    }
    
    private var startPointColor: Color {
        return pathfinding.startPoint != nil ? .primary : .gray
    }
    
    private var destinationText: String {
        if let endPoint = pathfinding.endPoint,
           let booth = findBoothNearPosition(endPoint) {
            return booth.name
        } else {
            return "Tulis Brand Incaranmu"
        }
    }
    
    private var destinationColor: Color {
        return pathfinding.endPoint != nil ? .primary : .gray
    }
    
    // Helper function to find booth near a position (for display purposes)
    private func findBoothNearPosition(_ position: GridPosition) -> Booth? {
        return crowdData.getBooths().first { booth in
            let adjacentPositions = pathfinding.getAdjacentPathPositions(for: booth)
            return adjacentPositions.contains(position)
        }
    }
    
    // Updated function to handle route selection
    private func handleRouteSelection(_ booth: Booth) {
        switch routeSelectorMode {
        case .start:
            // For starting point, find the closest adjacent position to the booth
            let adjacentPositions = pathfinding.getAdjacentPathPositions(for: booth)
            if let firstPosition = adjacentPositions.first {
                pathfinding.setStartPoint(firstPosition)
                isSelectingStartPoint = false // Clear the selection mode
            }
        case .destination:
            // For destination, use existing booth selection logic
            pathfinding.selectBoothAsDestination(booth)
            selectedBoothForDestination = booth
        }
    }
    
    // Update the handleBoothTap function to properly handle the flow
    private func handleBoothTap(_ booth: Booth) {
        if isSelectingStartPoint {
            // Handle start point selection
            let adjacentPositions = pathfinding.getAdjacentPathPositions(for: booth)
            if let firstPosition = adjacentPositions.first {
                pathfinding.setStartPoint(firstPosition)
                isSelectingStartPoint = false // Clear the selection mode
            }
        } else if pathfinding.startPoint != nil && pathfinding.endPoint == nil {
            // If we have a start point but no destination, allow setting destination
            pathfinding.selectBoothAsDestination(booth)
            selectedBoothForDestination = booth
        } else {
            // Handle normal booth selection (destination or details)
            pathfinding.clearPath()
            completedPathIndices.removeAll()
            selectedBoothForDestination = booth
            showBoothDetails = true
        }
    }
    
    private var filteredBooths: [Booth] {
        crowdData.getBooths()
    }
    
    private func getAllWalkablePositions() -> [GridPosition] {
        var walkablePositions: [GridPosition] = []
        
        for x in 0..<totalMapWidth {
            for y in 0..<totalMapHeight {
                let position = GridPosition(x: x, y: y)
                
                if let _ = pathfinding.gridGraph.node(atGridPosition: vector_int2(Int32(x), Int32(y))) {
                    walkablePositions.append(position)
                }
            }
        }
        
        return walkablePositions
    }
    
    private func switchToHall(_ section: ZoomSection) {
        withAnimation(.easeInOut(duration: 0.5)) {
            if section == .none {
                scale = 1.0
                lastOffset = .zero
                offset = .zero
                zoomedSection = .none
            } else {
                lastOffset = .zero
                offset = .zero
                zoomedSection = section
            }
        }
    }
    
    private func toggleCategoryFilter() {
        withAnimation(.easeInOut) {
            showCategoryFilter.toggle()
        }
    }
    
    private func analyzeCurrentPath() {
        print("🔍 Current Path Analysis:")
        print(pathfinding.analyzePath())
        
        let highCrowdAreas = crowdData.cctvs.filter { $0.peopleCount > 15 }
        print("📊 High crowd areas (>15 people):")
        for cctv in highCrowdAreas {
            print("  \(cctv.name): \(cctv.peopleCount) people at (\(cctv.position.x), \(cctv.position.y))")
        }
    }
    
    private var categoryFilterPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filter by Category")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Clear") {
                    selectedCategory = nil
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(BoothCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = selectedCategory == category ? nil : category
                    }) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(categoryColor(for: category))
                                .frame(width: 20, height: 20)
                            
                            Text(category.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(
                            selectedCategory == category ? 
                            Color.blue.opacity(0.2) : Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 3)
        .padding(.horizontal, 56)
    }
    
    private func categoryColor(for category: BoothCategory) -> Color {
        switch category {
        case .bodycare: return .purple
        case .haircare: return .brown
        case .lipcare: return .pink
        case .makeup: return .red
        case .perfume: return .mint
        case .skincare: return .cyan
        }
    }
    
    private func boothDetailsPanel(for booth: Booth) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booth.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Hall: \(booth.hall.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !booth.categories.isEmpty {
                        HStack(spacing: 4) {
                            Text("Categories:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(booth.categories, id: \.self) { category in
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(categoryColor(for: category))
                                        .frame(width: 8, height: 8)
                                    Text(category.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button("✕") {
                    withAnimation(.easeInOut) {
                        showBoothDetails = false
                        selectedBoothForDestination = nil
                    }
                }
                .font(.title2)
                .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button("Set as Destination") {
                    withAnimation(.easeInOut) {
                        pathfinding.selectBoothAsDestination(booth)
                        showBoothDetails = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button("Cancel") {
                    withAnimation(.easeInOut) {
                        showBoothDetails = false
                        selectedBoothForDestination = nil
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 3)
        .padding(.horizontal, 56)
    }
    
    private var pathfindingInstructions: some View {
        VStack(spacing: 8) {
            if pathfinding.endPoint == nil && pathfinding.startPoint == nil {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.red)
                    Text("Select your starting point and destination")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            } else if pathfinding.startPoint != nil && pathfinding.endPoint == nil {
                HStack {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.orange)
                    Text("Now tap any booth on the map or use the route selector to choose your destination")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            } else if pathfinding.endPoint != nil && pathfinding.startPoint == nil {
                HStack {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.orange)
                    Text("Select your starting point using the route selector above")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            } else if !isNavigationActive {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Route calculated!")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Tap the green play button to start navigation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Navigation active!")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Tap blue dots to mark progress • Tap red dot to finish")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 3)
        .padding(.horizontal, 56)
    }
    
    private func resetMapPosition() {
        withAnimation(.easeInOut) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
            zoomedSection = .none
        }
    }
    
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
    ContentView()
}

// Add this new component before the main EventMapView struct

struct BoothListSheet: View {
    let booths: [Booth]
    let mode: EventMapView.RouteSelectorMode
    let onBoothSelected: (Booth) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: BoothCategory? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Computed property for dynamic title
    private var sheetTitle: String {
        switch mode {
        case .start:
            return "Lagi Dimana?"
        case .destination:
            return "Mau Kemana?"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBarSection
                categoryFilterSection
                boothListSection
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(false)
            // Remove .presentationDragIndicator(.visible) from here
        }
    }
    
    // Break down the search bar into a separate computed property
    private var searchBarSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Tuliskan nama brand", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // Break down the category filters into a separate computed property
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                allCategoryButton
                
                ForEach(BoothCategory.allCases, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var allCategoryButton: some View {
        Button(action: {
            selectedCategory = nil
        }) {
            Text("All")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedCategory == nil ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedCategory == nil ? Color(red: 0.859, green: 0.157, blue: 0.306) : Color.gray.opacity(0.2))
                .clipShape(Capsule())
        }
    }
    
    private func categoryButton(for category: BoothCategory) -> some View {
        let isSelected = selectedCategory == category
        
        return Button(action: {
            selectedCategory = selectedCategory == category ? nil : category
        }) {
            Text(category.rawValue.capitalized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.859, green: 0.157, blue: 0.306) : Color.gray.opacity(0.2))
                .clipShape(Capsule())
        }
    }
    
    // Break down the booth list into a separate computed property
    private var boothListSection: some View {
        List {
            ForEach(groupedBooths.keys.sorted(), id: \.self) { letter in
                Section {
                    ForEach(Array(groupedBooths[letter, default: []].enumerated()), id: \.offset) { index, booth in
                        boothRow(for: booth, at: index, letter: letter)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func boothRow(for booth: Booth, at index: Int, letter: String) -> some View {
        HStack(spacing: 12) {
            // Show letter only for the first booth in each section
            if index == 0 {
                Text(letter)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.859, green: 0.157, blue: 0.306))
                    .frame(width: 30, alignment: .center)
            } else {
                // Empty space to align with other entries
                Spacer()
                    .frame(width: 30)
            }
            
            // Booth content
            Button(action: {
                onBoothSelected(booth)
            }) {
                boothContent(for: booth)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
    
    private func boothContent(for booth: Booth) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(booth.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                categoryIndicators(for: booth)
            }
            
            Spacer()
            
            Text(booth.hall.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func categoryIndicators(for booth: Booth) -> some View {
        HStack(spacing: 8) {
            if !booth.categories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(booth.categories.prefix(2), id: \.self) { category in
                        Circle()
                            .fill(categoryColor(for: category))
                            .frame(width: 8, height: 8)
                    }
                    if booth.categories.count > 2 {
                        Text("+\(booth.categories.count - 2)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var filteredBooths: [Booth] {
        let categoryFiltered: [Booth]
        if let selectedCategory = selectedCategory {
            categoryFiltered = booths.filter { $0.categories.contains(selectedCategory) }
        } else {
            categoryFiltered = booths
        }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { booth in
                let words = booth.name.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                return words.contains { word in
                    word.lowercased().hasPrefix(searchText.lowercased())
                }
            }
        }
    }
    
    private var groupedBooths: [String: [Booth]] {
        Dictionary(grouping: filteredBooths) { booth in
            String(booth.name.prefix(1).uppercased())
        }
    }
    
    private func categoryColor(for category: BoothCategory) -> Color {
        switch category {
        case .bodycare: return .purple
        case .haircare: return .brown
        case .lipcare: return .pink
        case .makeup: return .red
        case .perfume: return .mint
        case .skincare: return .cyan
        }
    }
}

extension EventMapView {
    
    // Missing computed properties for map interaction
    private var currentScale: CGFloat {
        scale
    }
    
    private var currentOffset: CGSize {
        offset
    }
    
    // Missing map content computed property
    private var mapContent: some View {
        ZStack {
            MapGridComponent(
                pathfinding: pathfinding,
                gridSize: gridSize,
                totalMapWidth: totalMapWidth,
                totalMapHeight: totalMapHeight,
                zoomedSection: zoomedSection
            )
            
            // Hall labels should be below interactive elements
            HallLabelsComponent(
                hallConfigs: pathfinding.getAllHallConfigs(),
                gridSize: gridSize,
                totalMapWidth: totalMapWidth,
                shouldShowHall: { _ in true }
            )
            .zIndex(0)
            .allowsHitTesting(false)
            
            // Path visualization should be on top for interaction
            if !pathfinding.currentPath.isEmpty {
                PathVisualizationComponent(
                    pathfinding: pathfinding,
                    gridSize: gridSize,
                    completedPathIndices: completedPathIndices,
                    isNavigationActive: isNavigationActive,
                    onCheckpointTap: handleCheckpointTap
                )
                .zIndex(1)
            }
            
            StartPointOverlayComponent(
                allWalkablePositions: getAllWalkablePositions(),
                gridSize: gridSize,
                showStartPoints: pathfinding.endPoint != nil && pathfinding.startPoint == nil,
                onStartPointTap: { pathfinding.setStartPoint($0) }
            )
            
            BoothsOverlayComponent(
                booths: filteredBooths,
                gridSize: gridSize,
                totalMapWidth: totalMapWidth,
                totalMapHeight: totalMapHeight,
                selectedCategory: selectedCategory,
                selectedBoothForDestination: selectedBoothForDestination,
                zoomedSection: zoomedSection,
                isNavigationActive: isNavigationActive,
                isSelectingStartPoint: isSelectingStartPoint,
                pathfinding: pathfinding, // Pass the pathfinding object
                onBoothTap: handleBoothTap
            )
            
            // Show CCTV overlay only when crowd info is toggled on
            if showCrowdInfo {
                CCTVOverlayComponent(
                    cctvs: crowdData.cctvs,
                    gridSize: gridSize
                )
            }
            
            PathfindingMarkersComponent(
                startPoint: pathfinding.startPoint,
                endPoint: pathfinding.endPoint,
                gridSize: gridSize
            )
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    // Update the endNavigation function to reset navigation state
    private func endNavigation() {
        // Clear the path and reset navigation state
        pathfinding.clearPath()
        completedPathIndices.removeAll()
        isNavigationActive = false // Reset navigation state
        
        // Optionally show a completion message or perform other cleanup
        print("🎉 Navigation completed successfully!")
    }
    
    // Missing map gestures
    private var mapGestures: some Gesture {
        SimultaneousGesture(
            // Pan gesture
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                },
            
            // Magnification gesture
            MagnificationGesture()
                .onChanged { value in
                    scale = value
                }
                .onEnded { value in
                    scale = max(0.5, min(3.0, value))
                }
        )
    }
    
    // Missing checkpoint tap handler
    private func handleCheckpointTap(_ pathIndex: Int) {
        if completedPathIndices.contains(pathIndex) {
            // If already completed, remove it and all subsequent checkpoints
            completedPathIndices = Set(completedPathIndices.filter { $0 < pathIndex })
        } else {
            // Mark this checkpoint and all previous ones as completed
            for index in 0...pathIndex {
                completedPathIndices.insert(index)
            }
            
            // Check if this is the final checkpoint (last node in path)
            if pathIndex == pathfinding.currentPath.count - 1 {
                // End the navigation
                withAnimation(.easeInOut) {
                    endNavigation()
                }
            }
        }
    }
    
    // Missing crowd info button
    private var crowdInfoButton: some View {
        Button(action: {
            showCrowdInfo.toggle()
        }) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(showCrowdInfo ? Color(red: 0.7, green: 0.1, blue: 0.25) : Color(red: 0.859, green: 0.157, blue: 0.306))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .padding(.leading, 56)
    }
    
    // Missing map navigation button
    private var mapNavigationButton: some View {
        ZStack {
            // Main map button
            Button(action: {
                showMapOptions.toggle()
            }) {
                Image(systemName: "map.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(showMapOptions ? Color(red: 0.7, green: 0.1, blue: 0.25) : Color(red: 0.859, green: 0.157, blue: 0.306))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            
            // Options panel
            if showMapOptions {
                VStack(spacing: 8) {
                    mapOptionButton(title: "Fit to Screen", action: { switchToHall(.none) })
                    mapOptionButton(title: "Hall A", action: { switchToHall(.hallA) })
                    mapOptionButton(title: "Hall B", action: { switchToHall(.hallB) })
                    mapOptionButton(title: "Hall C", action: { switchToHall(.hallC) })
                }
                .padding(12)
                .frame(width: 120)
                .background(Color(red: 0.859, green: 0.157, blue: 0.306))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .position(x: 38, y: -100)
            }
        }
        .frame(width: 120, height: 56)
        .padding(.trailing, 20)
    }
    
    // Missing map option button helper
    private func mapOptionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            showMapOptions = false
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
