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
            hallLabels
            hallDividers
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
                    // Center the hall horizontally
                    let leftPadding = (totalMapWidth - config.width) / 2
                    
                    // Left padding to center the hall
                    ForEach(0..<leftPadding, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: gridSize, height: gridSize)
                    }
                    
                    // Actual hall content
                    ForEach(0..<config.width, id: \.self) { x in
                        Rectangle()
                            .fill(hallBackgroundColor(for: config.hall))
                            .frame(width: gridSize, height: gridSize)
                            .border(Color.gray.opacity(0.3), width: 0.5)
                            .opacity(hallOpacity(for: config.hall))
                    }
                    
                    // Right padding to center the hall
                    ForEach((leftPadding + config.width)..<totalMapWidth, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: gridSize, height: gridSize)
                    }
                }
            }
        }
        .position(x: CGFloat(totalMapWidth) * gridSize / 2,
                  y: CGFloat(config.yStart + config.yEnd) * gridSize / 2)
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
        ZStack {
            if case .none = zoomedSection {
                // Divider between Hall C and Hall B (after Hall C ends)
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: CGFloat(totalMapWidth) * gridSize, height: 3)
                    .position(x: CGFloat(totalMapWidth) * gridSize / 2, 
                             y: CGFloat(8) * gridSize - 1.5) // Position between halls
                
                // Divider between Hall B and Hall A (after Hall B ends)
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: CGFloat(totalMapWidth) * gridSize, height: 3)
                    .position(x: CGFloat(totalMapWidth) * gridSize / 2, 
                             y: CGFloat(16) * gridSize - 1.5) // Position between halls
            }
        }
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
