import SwiftUI
import simd  // Add this import for vector_int2

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
    
    var hall: Hall? {
        switch self {
        case .none: return nil
        case .hallA: return .hallA
        case .hallB: return .hallB
        case .hallC: return .hallC
        }
    }
}

struct EventMapView: View {
    @StateObject private var crowdData = CrowdData()
    @StateObject private var pathfinding: EventMapPathfinding
    
    // Initialize pathfinding with the same crowdData instance
    init() {
        let crowdData = CrowdData()
        self._crowdData = StateObject(wrappedValue: crowdData)
        self._pathfinding = StateObject(wrappedValue: EventMapPathfinding(width: 12, height: 22, crowdData: crowdData))
    }
    
    // Zoom and section properties
    @State private var zoomedSection: ZoomSection = .none
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Category filter properties
    @State private var selectedCategory: BoothCategory? = nil
    @State private var showCategoryFilter = false
    
    // Updated state variables for new flow
    @State private var selectedBoothForDestination: Booth? = nil
    @State private var showBoothDetails = false
    
    // Add state to track completed path segments
    @State private var completedPathIndices: Set<Int> = []

    private let gridSize: CGFloat = 40
    private let totalMapWidth: Int = 12
    private let totalMapHeight: Int = 22
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Map layer
            mapContent
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .gesture(mapGestures)
            
            // UI Controls
            VStack {
                // Top: Hall selector and category filter
                HStack {
                    hallSelector
                    Spacer()
                    categoryFilterButton
                }
                
                // Booth details panel (new)
                if showBoothDetails, let selectedBooth = selectedBoothForDestination {
                    boothDetailsPanel(for: selectedBooth)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Pathfinding instructions - always show when relevant
                if pathfinding.endPoint != nil || pathfinding.startPoint != nil {
                    pathfindingInstructions
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Category filter panel
                if showCategoryFilter {
                    categoryFilterPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer()
                
                // Bottom: Map controls
                if case .none = zoomedSection {
                    mapControlPanel
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // Computed properties for current scale and offset
    private var currentScale: CGFloat {
        if case .none = zoomedSection {
            return scale
        } else {
            return scale * 1.5 // Zoom into the selected hall while keeping user's zoom level
        }
    }
    
    private var currentOffset: CGSize {
        if case .none = zoomedSection {
            return CGSize(width: lastOffset.width + offset.width, 
                         height: lastOffset.height + offset.height)
        } else {
            // Calculate offset to center the selected hall, but keep drag functionality
            let yOffset: CGFloat = {
                switch zoomedSection {
                case .hallC: return 150   // Move up to show Hall C
                case .hallB: return 0     // Center for Hall B
                case .hallA: return -150  // Move down to show Hall A
                default: return 0
                }
            }()
            // Allow dragging while zoomed into a hall
            return CGSize(width: lastOffset.width + offset.width, 
                         height: lastOffset.height + offset.height + yOffset)
        }
    }
    
    // Map content
    private var mapContent: some View {
        ZStack {
            hallGrids
            pathOverlay
            adjacentPathsOverlay
            boothsOverlay
            pathfindingMarkersOverlay
            hallLabels
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    // Path overlay - fix both line and checkpoint positioning
    private var pathOverlay: some View {
        ZStack {
            // Draw lines between path points (non-interactive)
            ZStack {
                ForEach(0..<max(0, pathfinding.currentPath.count - 1), id: \.self) { index in
                    let startNode = pathfinding.currentPath[index]
                    let endNode = pathfinding.currentPath[index + 1]
                    
                    let isCompleted = completedPathIndices.contains(index)
                    let lineColor = isCompleted ? Color.gray : Color.blue
                    
                    let startPos = CGPoint(
                        x: CGFloat(startNode.gridPosition.x) * gridSize + gridSize/2,
                        y: CGFloat(startNode.gridPosition.y) * gridSize // Removed + gridSize/2 to shift up
                    )
                    let endPos = CGPoint(
                        x: CGFloat(endNode.gridPosition.x) * gridSize + gridSize/2,
                        y: CGFloat(endNode.gridPosition.y) * gridSize // Removed + gridSize/2 to shift up
                    )
                    
                    Path { path in
                        path.move(to: startPos)
                        path.addLine(to: endPos)
                    }
                    .stroke(lineColor, lineWidth: 3)
                    .opacity(0.8)
                }
            }
            .allowsHitTesting(false) // Lines don't need to be tappable
            
            // Draw checkpoints at direction changes (interactive)
            ForEach(Array(getDirectionChangeIndices().enumerated()), id: \.offset) { arrayIndex, pathIndex in
                let node = pathfinding.currentPath[pathIndex]
                let isCompleted = completedPathIndices.contains(pathIndex)
                let isLastCheckpoint = pathIndex == pathfinding.currentPath.count - 1
                let fillColor = isCompleted ? Color.gray : (isLastCheckpoint ? Color.red : Color.blue)
                
                let xPos = CGFloat(node.gridPosition.x) * gridSize + gridSize/2
                let yPos = CGFloat(node.gridPosition.y) * gridSize // Removed + gridSize/2 to shift up
                
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
                        handleCheckpointTap(at: pathIndex)
                    }
            }
        }
    }
    
    // Add this helper function to find direction changes
    private func getDirectionChangeIndices() -> [Int] {
        guard pathfinding.currentPath.count > 2 else {
            // If path has 2 or fewer points, show start and end
            return Array(0..<pathfinding.currentPath.count)
        }
        
        var indices: [Int] = []
        
        // Always include the start point
        indices.append(0)
        
        // Check for direction changes
        for i in 1..<pathfinding.currentPath.count - 1 {
            let prevNode = pathfinding.currentPath[i - 1]
            let currentNode = pathfinding.currentPath[i]
            let nextNode = pathfinding.currentPath[i + 1]
            
            // Calculate direction vectors
            let directionToCurrent = (
                x: currentNode.gridPosition.x - prevNode.gridPosition.x,
                y: currentNode.gridPosition.y - prevNode.gridPosition.y
            )
            
            let directionFromCurrent = (
                x: nextNode.gridPosition.x - currentNode.gridPosition.x,
                y: nextNode.gridPosition.y - currentNode.gridPosition.y
            )
            
            // If direction changes, this is a turn point
            if directionToCurrent.x != directionFromCurrent.x || directionToCurrent.y != directionFromCurrent.y {
                indices.append(i)
            }
        }
        
        // Always include the end point
        indices.append(pathfinding.currentPath.count - 1)
        
        return indices
    }
    
    // Adjacent paths overlay (when selecting start/end points)
    private var adjacentPathsOverlay: some View {
        ZStack {
            // Show adjacent paths when user has set destination but hasn't set start point yet
            if pathfinding.endPoint != nil && pathfinding.startPoint == nil {
                // Get all valid walkable positions as potential starting points
                let allWalkablePositions = getAllWalkablePositions()
                
                ForEach(allWalkablePositions, id: \.self) { position in
                    let xPosition = CGFloat(position.x) * gridSize + gridSize/2
                    let yPosition = CGFloat(position.y) * gridSize
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .position(x: xPosition, y: yPosition)
                        .opacity(0.7)
                        .onTapGesture {
                            pathfinding.setStartPoint(position)
                        }
                }
            }
        }
    }
    
    // Pathfinding markers overlay
    private var pathfindingMarkersOverlay: some View {
        ZStack {
            // Start point marker
            if let startPoint = pathfinding.startPoint {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .position(
                        x: CGFloat(startPoint.x) * gridSize + gridSize/2,
                        y: CGFloat(startPoint.y) * gridSize // Removed + gridSize/2 to shift up
                    )
            }
            
            // End point marker
            if let endPoint = pathfinding.endPoint {
                Image(systemName: "flag.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .position(
                        x: CGFloat(endPoint.x) * gridSize + gridSize/2,
                        y: CGFloat(endPoint.y) * gridSize // Removed + gridSize/2 to shift up
                    )
            }
        }
        .allowsHitTesting(false) // Add this line to disable touch interaction
    }
    
    // Hall grids
    private var hallGrids: some View {
        ZStack {
            ForEach(pathfinding.getAllHallConfigs(), id: \.hall) { config in
                hallGrid(config: config)
            }
        }
    }
    
    // Individual hall grid
    private func hallGrid(config: EventMapPathfinding.HallConfig) -> some View {
        VStack(spacing: 0) {
            ForEach(config.yStart...config.yEnd, id: \.self) { y in
                HStack(spacing: 0) {
                    // Create a full-width row that matches the totalMapWidth
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
    
    // Helper function to determine if a grid position is within a hall
    private func isValidHallPosition(x: Int, y: Int, config: EventMapPathfinding.HallConfig) -> Bool {
        let leftPadding = (totalMapWidth - config.width) / 2
        let rightBound = leftPadding + config.width
        
        return x >= leftPadding && x < rightBound && y >= config.yStart && y <= config.yEnd
    }
    
    // Booths overlay - updated to remove crowd level indicators
    private var boothsOverlay: some View {
        ZStack {
            ForEach(filteredBooths) { booth in
                if shouldShowHall(booth.hall) {
                    boothView(booth: booth)
                        .position(
                            x: CGFloat(booth.gridPosition.x) * gridSize + (booth.name.contains("2x2") ? gridSize : gridSize/2),
                            y: CGFloat(booth.gridPosition.y) * gridSize + (booth.name.contains("2x2") ? gridSize : gridSize/2) - gridSize/2
                        )
                }
            }
            
            // Add CCTV overlay
            cctvOverlay
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    // New CCTV overlay
    private var cctvOverlay: some View {
        ZStack {
            ForEach(crowdData.cctvs) { cctv in
                VStack(spacing: 2) {
                    // CCTV icon
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                    
                    // People count
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
            
            // Pathway crowd visualization
            pathwayCrowdOverlay
        }
        .allowsHitTesting(false) // Add this line to disable touch interaction
    }
    
    // Pathway crowd visualization
    private var pathwayCrowdOverlay: some View {
        ZStack {
            ForEach(crowdData.cctvs) { cctv in
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
        .allowsHitTesting(false) // Add this line to disable touch interaction
    }
    
    // Color based on people count
    private func crowdColorForCount(_ count: Int) -> Color {
        switch count {
        case 0...5: return .green      // Low crowd
        case 6...10: return .yellow    // Medium crowd
        case 11...15: return .orange   // High crowd
        default: return .red           // Very high crowd
        }
    }

    // Updated booth view - removed crowd level indicator
    private func boothView(booth: Booth) -> some View {
        let is2x2Booth = booth.name.contains("2x2")
        let boothSize = is2x2Booth ? gridSize * 2 : gridSize
        let isHighlighted = selectedCategory != nil && booth.categories.contains(selectedCategory!)
        let isSelectedForDestination = selectedBoothForDestination?.id == booth.id
        
        return Rectangle()
            .fill(boothColor(for: booth))
            .frame(width: boothSize, height: boothSize)
            .border(
                isSelectedForDestination ? Color.red : 
                (isHighlighted ? Color.yellow : boothBorderColor(for: booth)), 
                width: isSelectedForDestination ? 3 : (isHighlighted ? 3 : 1)
            )
            .opacity(boothOpacity(for: booth))
            .overlay(
                VStack {
                    // Category indicators (top)
                    if !booth.categories.isEmpty && boothSize >= gridSize {
                        HStack(spacing: 2) {
                            ForEach(booth.categories.prefix(2), id: \.self) { category in
                                Circle()
                                    .fill(categoryColor(for: category))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                    
                    // Show booth name if selected
                    if isSelectedForDestination && boothSize >= gridSize {
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
            )
            .onTapGesture {
                handleBoothTap(booth)
            }
    }
    
    // Updated function to handle booth taps with the new flow
    private func handleBoothTap(_ booth: Booth) {
        // Reset any existing path
        pathfinding.clearPath()
        completedPathIndices.removeAll()
        
        // Select booth for destination details
        selectedBoothForDestination = booth
        showBoothDetails = true
    }

    // Booth opacity based on single category filter
    private func boothOpacity(for booth: Booth) -> Double {
        let baseOpacity = hallOpacity(for: booth.hall)
        
        if let selectedCategory = selectedCategory {
            let matchesFilter = booth.categories.contains(selectedCategory)
            return matchesFilter ? baseOpacity : baseOpacity * 0.3
        } else {
            return baseOpacity
        }
    }
    
    // Hall labels
    private var hallLabels: some View {
        ZStack {
            ForEach(pathfinding.getAllHallConfigs(), id: \.hall) { config in
                if shouldShowHall(config.hall) {
                    Text(config.hall.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                        .position(x: CGFloat(totalMapWidth) * gridSize / 2, // Center horizontally
                                  y: CGFloat(config.yStart + 1) * gridSize)
                }
            }
        }
    }
    
    // Hall dividers
    private var hallDividers: some View {
        EmptyView()  // This will remove all dividers
    }
    
    // Hall background colors
    private func hallBackgroundColor(for hall: Hall) -> Color {
        switch hall {
        case .hallC: return Color.orange.opacity(0.1)   // Hall C (Top)
        case .hallB: return Color.green.opacity(0.1)    // Hall B (Middle)
        case .hallA: return Color.blue.opacity(0.1)     // Hall A (Bottom)
        }
    }
    
    // Check if hall should be shown based on zoom
    private func shouldShowHall(_ hall: Hall) -> Bool {
        return true // Always show all halls
    }
    
    // Add this missing function
    private func hallOpacity(for hall: Hall) -> Double {
        switch zoomedSection {
        case .none: return 1.0
        case .hallA: return hall == .hallA ? 1.0 : 0.3
        case .hallB: return hall == .hallB ? 1.0 : 0.3
        case .hallC: return hall == .hallC ? 1.0 : 0.3
        }
    }
    
    // Hall selector
    private var hallSelector: some View {
        Menu {
            ForEach(ZoomSection.allCases, id: \.self) { section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        if section == .none {
                            // Reset everything when selecting "All Halls"
                            scale = 1.0
                            lastOffset = .zero
                            offset = .zero
                            zoomedSection = .none
                        } else {
                            // Reset the pan offset when selecting a specific hall
                            lastOffset = .zero
                            offset = .zero
                            zoomedSection = section
                        }
                    }
                }) {
                    HStack {
                        Text(section.title)
                        if zoomedSection == section {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "building.2")
                    .font(.system(size: 18))
                Text(zoomedSection.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .cornerRadius(20)
            .shadow(radius: 3)
        }
    }
    
    // Map controls
    private var mapControlPanel: some View {
        HStack(spacing: 16) {
            Button(action: resetMapPosition) { 
                Image(systemName: "house.fill")
                    .font(.system(size: 18))
            }
            
            Button(action: zoomOut) { 
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 18))
            }
            
            Button(action: zoomIn) { 
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 18))
            }
            
            Button(action: {
                print("🔍 Current Path Analysis:")
                print(pathfinding.analyzePath())
                
                // Print a summary
                let highCrowdAreas = crowdData.cctvs.filter { $0.peopleCount > 15 }
                print("📊 High crowd areas (>15 people):")
                for cctv in highCrowdAreas {
                    print("  \(cctv.name): \(cctv.peopleCount) people at (\(cctv.position.x), \(cctv.position.y))")
                }
            }) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
            }
            .tint(.orange)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .cornerRadius(20)
        .shadow(radius: 3)
    }
    
    // Map gestures
    private var mapGestures: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    // Allow pinch zoom in all states
                    scale = max(0.5, min(3.0, value))
                },
            
            DragGesture()
                .onChanged { value in
                    // Allow dragging in all states
                    offset = value.translation
                }
                .onEnded { value in
                    // Update lastOffset in all states
                    lastOffset.width += offset.width
                    lastOffset.height += offset.height
                    offset = .zero
                }
        )
    }
    
    // Map control functions
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
    
    // Booth color based on hall
    private func boothColor(for booth: Booth) -> Color {
        switch booth.hall {
        case .hallA: return Color.blue.opacity(0.7)
        case .hallB: return Color.green.opacity(0.7)
        case .hallC: return Color.orange.opacity(0.7)
        }
    }
    
    // Booth border color
    private func boothBorderColor(for booth: Booth) -> Color {
        switch booth.hall {
        case .hallA: return Color.blue
        case .hallB: return Color.green
        case .hallC: return Color.orange
        }
    }
    
    // Crowd indicator color based on level
    private func crowdIndicatorColor(level: Float) -> Color {
        switch level {
        case 0.0..<0.3: return .green      // Low crowd
        case 0.3..<0.6: return .yellow     // Medium crowd
        case 0.6..<0.8: return .orange     // High crowd
        default: return .red               // Very high crowd
        }
    }
    
    // Pathfinding instructions
    private var pathfindingInstructions: some View {
        VStack(spacing: 8) {
            if pathfinding.endPoint == nil {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.red)
                    Text("Tap any booth to see details and set as destination")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            } else if pathfinding.startPoint == nil {
                HStack {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.green)
                    Text("Tap a green circle on any pathway to set your starting point")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            } else {
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
    }
    
    // Add the missing handleCheckpointTap function
    private func handleCheckpointTap(at index: Int) {
        let isLastCheckpoint = index == pathfinding.currentPath.count - 1
        
        if isLastCheckpoint {
            // Last checkpoint tapped - remove the entire pathway
            withAnimation(.easeInOut(duration: 0.5)) {
                pathfinding.clearPath()
                completedPathIndices.removeAll()
                selectedBoothForDestination = nil
            }
        } else {
            // Regular checkpoint tapped - mark previous segments as grey
            withAnimation(.easeInOut(duration: 0.3)) {
                // Mark all line segments up to (but not including) this checkpoint as completed
                // Line segments are indexed from 0 to pathfinding.currentPath.count - 2
                // When you tap checkpoint at index i, you want to mark line segments 0 to i-1 as completed
                for i in 0..<index {
                    completedPathIndices.insert(i)
                }
            }
        }
    }
    
    // Add these missing properties and functions to your EventMapView struct:

    // Add this computed property for filtered booths
    private var filteredBooths: [Booth] {
        crowdData.getBooths()
    }

    // Add the missing category filter button
    private var categoryFilterButton: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                showCategoryFilter.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "line.horizontal.3.decrease.circle")
                    .font(.system(size: 18))
                Text("Filter")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .cornerRadius(20)
            .shadow(radius: 3)
        }
    }

    // Add the missing category filter panel
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
    }

    // Add the missing category color function
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
    
    // New booth details panel
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
    }

    // Helper function to get all walkable positions
    private func getAllWalkablePositions() -> [GridPosition] {
        var walkablePositions: [GridPosition] = []
        
        // Iterate through all possible grid positions
        for x in 0..<totalMapWidth {
            for y in 0..<totalMapHeight {
                let position = GridPosition(x: x, y: y)
                
                // Check if this position is walkable using the pathfinding graph
                if let _ = pathfinding.gridGraph.node(atGridPosition: vector_int2(Int32(x), Int32(y))) {
                    walkablePositions.append(position)
                }
            }
        }
        
        return walkablePositions
    }
}
