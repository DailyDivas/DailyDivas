import SwiftUI

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
    @State private var pathfinding: EventMapPathfinding?
    
    // Zoom and section properties
    @State private var zoomedSection: ZoomSection = .none
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let gridSize: CGFloat = 40
    private let totalMapWidth: Int = 12  // Use the largest hall width
    private let totalMapHeight: Int = 22 // Sum of all hall heights
    
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
                // Top: Hall selector
                HStack {
                    Spacer()
                    hallSelector
                    Spacer()
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
        .onAppear {
            setupPathfinding()
        }
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
            boothsOverlay
            hallLabels
            // hallDividers  // Remove this line to eliminate hall separators
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    // Hall grids
    private var hallGrids: some View {
        ZStack {
            if let pathfinding = pathfinding {
                ForEach(pathfinding.getAllHallConfigs(), id: \.hall) { config in
                    hallGrid(config: config)
                }
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
    
    // Individual booth view
    private func boothView(booth: Booth) -> some View {
        let is2x2Booth = booth.name.contains("2x2")
        let boothSize = is2x2Booth ? gridSize * 2 : gridSize
        
        return Rectangle()
            .fill(boothColor(for: booth))
            .frame(width: boothSize, height: boothSize)
            .border(boothBorderColor(for: booth), width: 1)
            .opacity(hallOpacity(for: booth.hall))
            .overlay(
                // Crowd level indicator
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(crowdIndicatorColor(level: booth.crowdLevel))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
                .padding(2)
            )
            .onTapGesture {
                // Handle booth tap - could show details, etc.
                print("Tapped booth: \(booth.name), Crowd: \(booth.crowdLevel)")
            }
    }
    
    // Booths overlay - fixed positioning for alignment
    private var boothsOverlay: some View {
        ZStack {
            ForEach(crowdData.booths) { booth in
                if shouldShowHall(booth.hall) {
                    boothView(booth: booth)
                        .position(
                            x: CGFloat(booth.gridPosition.x) * gridSize + (booth.name.contains("2x2") ? gridSize : gridSize/2),
                            y: CGFloat(booth.gridPosition.y) * gridSize + (booth.name.contains("2x2") ? gridSize : gridSize/2) - gridSize/2 // Shifted up by half a grid
                        )
                }
            }
        }
        .frame(width: CGFloat(totalMapWidth) * gridSize, 
               height: CGFloat(totalMapHeight) * gridSize)
    }
    
    // Booth colors based on hall
    private func boothColor(for booth: Booth) -> Color {
        switch booth.hall {
        case .hallC: return Color.orange.opacity(0.8)   // Hall C booths
        case .hallB: return Color.green.opacity(0.8)    // Hall B booths  
        case .hallA: return Color.blue.opacity(0.8)     // Hall A booths
        }
    }
    
    // Booth border colors
    private func boothBorderColor(for booth: Booth) -> Color {
        booth.isActive ? Color.primary : Color.red
    }
    
    // Crowd indicator colors
    private func crowdIndicatorColor(level: Float) -> Color {
        switch level {
        case 0.0..<0.3: return .green
        case 0.3..<0.7: return .yellow
        default: return .red
        }
    }
    
    // Hall labels
    private var hallLabels: some View {
        ZStack {
            if let pathfinding = pathfinding {
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
    
    // Setup pathfinding
    private func setupPathfinding() {
        pathfinding = EventMapPathfinding(width: Int32(totalMapWidth), 
                                         height: Int32(totalMapHeight), 
                                         crowdData: crowdData)
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
}

#Preview {
    EventMapView()
}
