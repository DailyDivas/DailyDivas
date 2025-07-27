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
    let onCheckpointTap: (Int) -> Void
    
    var body: some View {
        ZStack {
            // Path lines
            pathLines
            
            // Checkpoints
            pathCheckpoints
        }
    }
    
    private var pathLines: some View {
        ZStack {
            ForEach(0..<max(0, pathfinding.currentPath.count - 1), id: \.self) { index in
                let startNode = pathfinding.currentPath[index]
                let endNode = pathfinding.currentPath[index + 1]
                
                let isCompleted = completedPathIndices.contains(index)
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
                        onTap: { onBoothTap(booth) }
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
                VStack {
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
    @State private var showMapOptions = false // Add this new state
    @State private var showCrowdInfo = false // Add this new state for crowd button
    @State private var showBoothList = false // Add this new state for booth list sheet

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
                // Add search button at the top
                HStack {
                    Spacer()
                    Button(action: {
                        showBoothList = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.859, green: 0.157, blue: 0.306))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
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
            
            // Add both navigation buttons
            VStack {
                Spacer()
                HStack {
                    crowdInfoButton
                    Spacer()
                    mapNavigationButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showBoothList) {
            BoothListSheet(
                booths: crowdData.getBooths(),
                onBoothSelected: { booth in
                    showBoothList = false
                    handleBoothTap(booth)
                }
            )
        }
    }
    
    // Add this new computed property for the crowd info button
    private var crowdInfoButton: some View {
        Button(action: {
            showCrowdInfo.toggle()
        }) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(showCrowdInfo ? Color(red: 0.7, green: 0.1, blue: 0.25) : Color(red: 0.859, green: 0.157, blue: 0.306)) // #DB284E
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .padding(.leading, 42)
    }
    
    // Add this new computed property for the map navigation button
    private var mapNavigationButton: some View {
        ZStack {
            // Main map button (always stays in the same position)
            Button(action: {
                showMapOptions.toggle()
            }) {
                Image(systemName: "map.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(showMapOptions ? Color(red: 0.7, green: 0.1, blue: 0.25) : Color(red: 0.859, green: 0.157, blue: 0.306)) // Darker when active
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            
            // Options panel (positioned absolutely above the main button)
            if showMapOptions {
                VStack(spacing: 8) {
                    mapOptionButton(title: "Hall C", action: { switchToHall(.hallC) })
                    mapOptionButton(title: "Hall B", action: { switchToHall(.hallB) })
                    mapOptionButton(title: "Hall A", action: { switchToHall(.hallA) })
                    mapOptionButton(title: "Fit to Screen", action: { switchToHall(.none) })
                }
                .padding(12)
                .frame(width: 120) // Fixed width to prevent expansion
                .background(Color(red: 0.859, green: 0.157, blue: 0.306)) // #DB284E
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .position(x: 60, y: -100) // Absolute positioning relative to the button
            }
        }
        .frame(width: 120, height: 56)
        .padding(.trailing, 12)// Fixed frame size
    }
    
    // Add this helper function for individual option buttons
    private func mapOptionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            showMapOptions = false
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity) // This will work within the fixed container width
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private var mapContent: some View {
        ZStack {
            MapGridComponent(
                pathfinding: pathfinding,
                gridSize: gridSize,
                totalMapWidth: totalMapWidth,
                totalMapHeight: totalMapHeight,
                zoomedSection: zoomedSection
            )
            
            if !pathfinding.currentPath.isEmpty {
                PathVisualizationComponent(
                    pathfinding: pathfinding,
                    gridSize: gridSize,
                    completedPathIndices: completedPathIndices,
                    onCheckpointTap: handleCheckpointTap
                )
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
            
            HallLabelsComponent(
                hallConfigs: pathfinding.getAllHallConfigs(),
                gridSize: gridSize,
                totalMapWidth: totalMapWidth,
                shouldShowHall: { _ in true }
            )
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    private var currentScale: CGFloat {
        if case .none = zoomedSection {
            return scale
        } else {
            return scale * 1.5
        }
    }
    
    private var currentOffset: CGSize {
        if case .none = zoomedSection {
            return CGSize(width: lastOffset.width + offset.width, 
                         height: lastOffset.height + offset.height)
        } else {
            let yOffset: CGFloat = {
                switch zoomedSection {
                case .hallC: return 150
                case .hallB: return 0
                case .hallA: return -150
                default: return 0
                }
            }()
            return CGSize(width: lastOffset.width + offset.width, 
                         height: lastOffset.height + offset.height + yOffset)
        }
    }
    
    private var mapGestures: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(0.5, min(3.0, value))
                },
            
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { value in
                    lastOffset.width += offset.width
                    lastOffset.height += offset.height
                    offset = .zero
                }
        )
    }
    
    private func handleBoothTap(_ booth: Booth) {
        pathfinding.clearPath()
        completedPathIndices.removeAll()
        selectedBoothForDestination = booth
        showBoothDetails = true
    }
    
    private func handleCheckpointTap(at index: Int) {
        let isLastCheckpoint = index == pathfinding.currentPath.count - 1
        
        if isLastCheckpoint {
            withAnimation(.easeInOut(duration: 0.5)) {
                pathfinding.clearPath()
                completedPathIndices.removeAll()
                selectedBoothForDestination = nil
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                for i in 0..<index {
                    completedPathIndices.insert(i)
                }
            }
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
    let onBoothSelected: (Booth) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: BoothCategory? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBarSection
                categoryFilterSection
                boothListSection
            }
            .navigationTitle("Mau kemana?")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
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
