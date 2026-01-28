//
//  SankeySwift.swift
//  SankeySwift
//
//  A native SwiftUI Sankey diagram library for iOS, macOS, tvOS, watchOS, and visionOS.
//
//  MIT License
//

import SwiftUI

// MARK: - Models

/// Represents a node in the Sankey diagram
public struct SankeyNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let color: Color
    public let label: String

    public init(_ id: String, color: Color = .blue, label: String? = nil) {
        self.id = id
        self.color = color
        self.label = label ?? id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SankeyNode, rhs: SankeyNode) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a link/flow between two nodes
public struct SankeyLink: Identifiable, Sendable {
    public let id = UUID()
    public let value: Double
    public let sourceId: String
    public let targetId: String
    public let color: Color?

    public init(_ value: Double, from sourceId: String, to targetId: String, color: Color? = nil) {
        self.value = value
        self.sourceId = sourceId
        self.targetId = targetId
        self.color = color
    }
}

/// Container for all Sankey diagram data
public struct SankeyData: Sendable {
    public let nodes: [SankeyNode]
    public let links: [SankeyLink]

    // Pre-computed lookup dictionary for O(1) access
    let nodeById: [String: SankeyNode]

    public init(nodes: [SankeyNode], links: [SankeyLink], mergeLinks: Bool = true) {
        self.nodes = nodes
        self.nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        if mergeLinks {
            // Merge links with same source and target
            var mergedLinksDict: [String: SankeyLink] = [:]

            for link in links {
                let key = "\(link.sourceId)->\(link.targetId)"

                if let existing = mergedLinksDict[key] {
                    // Merge: sum values, keep first link's color
                    mergedLinksDict[key] = SankeyLink(
                        existing.value + link.value,
                        from: link.sourceId,
                        to: link.targetId,
                        color: existing.color ?? link.color
                    )
                } else {
                    mergedLinksDict[key] = link
                }
            }

            self.links = Array(mergedLinksDict.values)
        } else {
            self.links = links
        }
    }
}

/// Value format for displaying node values
public enum SankeyValueFormat: Sendable {
    /// Default integer format (e.g., "18")
    case integer
    /// Custom formatter with full control
    case custom(@Sendable (Double) -> String)

    public func format(_ value: Double) -> String {
        switch self {
        case .integer:
            return String(format: "%.0f", value)
        case .custom(let formatter):
            return formatter(value)
        }
    }
}

/// Label position relative to the diagram
public enum SankeyLabelPosition: Sendable {
    /// Labels inside the diagram (next to nodes)
    case inside
    /// Labels outside the diagram (first column on left, last column on right, middle hidden)
    case outside
}

/// Context provided to custom label views
public struct SankeyLabelContext: Sendable {
    public let node: SankeyNode
    public let value: Double
    public let formattedValue: String
    public let isFirstColumn: Bool
    public let isLastColumn: Bool
    public let column: Int
    public let totalColumns: Int
}

/// Context provided to custom link annotation views
public struct SankeyAnnotationContext: Sendable {
    public let link: SankeyLink
    public let sourceNode: SankeyNode
    public let targetNode: SankeyNode
    public let formattedValue: String
}

// MARK: - Layout Engine

/// Internal layout calculations for the Sankey diagram
struct SankeyLayout {
    struct LayoutNode {
        let node: SankeyNode
        var column: Int
        var row: Int
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var incomingValue: Double
        var outgoingValue: Double
        var totalColumns: Int
    }

    struct LayoutLink {
        let link: SankeyLink
        let thickness: CGFloat
        // Pre-computed coordinates for rendering
        let startX: CGFloat
        let startY: CGFloat
        let endX: CGFloat
        let endY: CGFloat
        // Pre-computed colors
        let sourceColor: Color
        let targetColor: Color
        // Pre-computed nodes for annotation context
        let sourceNode: SankeyNode
        let targetNode: SankeyNode
    }

    let nodes: [LayoutNode]
    let links: [LayoutLink]
    let columns: [[String]]

    init(data: SankeyData, size: CGSize, nodeWidth: CGFloat, nodePadding: CGFloat, columnPadding: CGFloat) {
        // Build adjacency information
        var outgoingLinks: [String: [SankeyLink]] = [:]
        var incomingLinks: [String: [SankeyLink]] = [:]
        var nodeValues: [String: (incoming: Double, outgoing: Double)] = [:]

        for node in data.nodes {
            outgoingLinks[node.id] = []
            incomingLinks[node.id] = []
            nodeValues[node.id] = (0, 0)
        }

        for link in data.links {
            outgoingLinks[link.sourceId]?.append(link)
            incomingLinks[link.targetId]?.append(link)
            nodeValues[link.sourceId]?.outgoing += link.value
            nodeValues[link.targetId]?.incoming += link.value
        }

        // Assign columns using topological sorting
        var nodeColumns: [String: Int] = [:]
        var columns: [[String]] = []

        // Find source nodes (no incoming links)
        var sourceNodes = data.nodes.filter { incomingLinks[$0.id]?.isEmpty ?? true }.map { $0.id }

        // If no pure source nodes, use all nodes with outgoing links
        if sourceNodes.isEmpty {
            sourceNodes = data.nodes.filter { !(outgoingLinks[$0.id]?.isEmpty ?? true) }.map { $0.id }
        }

        // BFS to assign columns
        var visited: Set<String> = []
        var queue = sourceNodes

        for nodeId in queue {
            nodeColumns[nodeId] = 0
        }

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            visited.insert(current)

            let currentCol = nodeColumns[current] ?? 0

            for link in outgoingLinks[current] ?? [] {
                let targetCol = max(nodeColumns[link.targetId] ?? 0, currentCol + 1)
                nodeColumns[link.targetId] = targetCol
                if !visited.contains(link.targetId) {
                    queue.append(link.targetId)
                }
            }
        }

        // Handle any unvisited nodes
        for node in data.nodes where !visited.contains(node.id) {
            nodeColumns[node.id] = 0
        }

        // Group nodes by column
        let maxColumn = nodeColumns.values.max() ?? 0
        for col in 0...maxColumn {
            let nodesInColumn = data.nodes.filter { nodeColumns[$0.id] == col }.map { $0.id }
            if !nodesInColumn.isEmpty {
                columns.append(nodesInColumn)
            }
        }

        self.columns = columns

        // Calculate available space
        let availableWidth = size.width - nodeWidth
        let columnSpacing = columns.count > 1 ? availableWidth / CGFloat(columns.count - 1) : 0

        // Calculate total values per column for height scaling
        var columnTotalValues: [CGFloat] = []
        for column in columns {
            var total: Double = 0
            for nodeId in column {
                let values = nodeValues[nodeId] ?? (0, 0)
                total += max(values.incoming, values.outgoing)
            }
            columnTotalValues.append(CGFloat(total))
        }

        let maxColumnValue = columnTotalValues.max() ?? 1
        let availableHeight = size.height - nodePadding * CGFloat((columns.map { $0.count }.max() ?? 1) - 1)
        let heightScale = maxColumnValue > 0 ? availableHeight / maxColumnValue : 1

        // Calculate node positions and sizes
        var layoutNodes: [String: LayoutNode] = [:]

        for (colIndex, column) in columns.enumerated() {
            let x = colIndex == 0 ? 0 : CGFloat(colIndex) * columnSpacing
            var currentY: CGFloat = 0

            // Calculate total height needed for this column
            var columnHeight: CGFloat = 0
            for nodeId in column {
                let values = nodeValues[nodeId] ?? (0, 0)
                let nodeValue = max(values.incoming, values.outgoing)
                columnHeight += CGFloat(nodeValue) * heightScale
            }
            columnHeight += nodePadding * CGFloat(column.count - 1)

            // Center the column vertically
            currentY = (size.height - columnHeight) / 2

            for nodeId in column {
                guard let node = data.nodes.first(where: { $0.id == nodeId }) else { continue }
                let values = nodeValues[nodeId] ?? (0, 0)
                let nodeValue = max(values.incoming, values.outgoing)
                let height = max(CGFloat(nodeValue) * heightScale, 4) // Minimum height of 4

                layoutNodes[nodeId] = LayoutNode(
                    node: node,
                    column: colIndex,
                    row: column.firstIndex(of: nodeId) ?? 0,
                    x: x,
                    y: currentY,
                    width: nodeWidth,
                    height: height,
                    incomingValue: values.incoming,
                    outgoingValue: values.outgoing,
                    totalColumns: columns.count
                )

                currentY += height + nodePadding
            }
        }

        self.nodes = data.nodes.compactMap { layoutNodes[$0.id] }

        // Calculate link positions
        var sourceYOffsets: [String: CGFloat] = [:]
        var targetYOffsets: [String: CGFloat] = [:]

        for nodeId in data.nodes.map({ $0.id }) {
            sourceYOffsets[nodeId] = 0
            targetYOffsets[nodeId] = 0
        }

        var layoutLinks: [LayoutLink] = []

        // Sort links by target position for better visual flow
        let sortedLinks = data.links.sorted { link1, link2 in
            let target1 = layoutNodes[link1.targetId]
            let target2 = layoutNodes[link2.targetId]
            return (target1?.y ?? 0) < (target2?.y ?? 0)
        }

        for link in sortedLinks {
            guard let sourceLayoutNode = layoutNodes[link.sourceId],
                  let targetLayoutNode = layoutNodes[link.targetId] else { continue }

            let thickness = max(CGFloat(link.value) * heightScale, 1)

            let sourceYOffset = sourceYOffsets[link.sourceId] ?? 0
            let targetYOffset = targetYOffsets[link.targetId] ?? 0

            // Pre-compute coordinates
            let startX = sourceLayoutNode.x + sourceLayoutNode.width
            let startY = sourceLayoutNode.y + sourceYOffset + thickness / 2
            let endX = targetLayoutNode.x
            let endY = targetLayoutNode.y + targetYOffset + thickness / 2

            // Pre-compute colors
            let sourceNode = data.nodeById[link.sourceId]
            let targetNode = data.nodeById[link.targetId]
            let sourceColor = link.color ?? sourceNode?.color ?? .gray
            let targetColor = targetNode?.color ?? sourceColor

            // Create placeholder nodes if not found (shouldn't happen with valid data)
            let resolvedSourceNode = sourceNode ?? SankeyNode(link.sourceId)
            let resolvedTargetNode = targetNode ?? SankeyNode(link.targetId)

            layoutLinks.append(LayoutLink(
                link: link,
                thickness: thickness,
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                sourceColor: sourceColor,
                targetColor: targetColor,
                sourceNode: resolvedSourceNode,
                targetNode: resolvedTargetNode
            ))

            sourceYOffsets[link.sourceId] = sourceYOffset + thickness
            targetYOffsets[link.targetId] = targetYOffset + thickness
        }

        self.links = layoutLinks
    }
}

// MARK: - Helper Extensions

extension View {
    @ViewBuilder
    func applyDynamicTypeSize(_ size: DynamicTypeSize?) -> some View {
        if let size = size {
            self.dynamicTypeSize(size)
        } else {
            self
        }
    }
}

// MARK: - Link Shape

/// A shape representing a Sankey link/flow path
struct SankeyLinkShape: Shape {
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let controlPoint1X = startX + (endX - startX) * 0.5
        let controlPoint2X = endX - (endX - startX) * 0.5

        var path = Path()

        // Top edge of the flow
        path.move(to: CGPoint(x: startX, y: startY - thickness / 2))
        path.addCurve(
            to: CGPoint(x: endX, y: endY - thickness / 2),
            control1: CGPoint(x: controlPoint1X, y: startY - thickness / 2),
            control2: CGPoint(x: controlPoint2X, y: endY - thickness / 2)
        )

        // Bottom edge of the flow
        path.addLine(to: CGPoint(x: endX, y: endY + thickness / 2))
        path.addCurve(
            to: CGPoint(x: startX, y: startY + thickness / 2),
            control1: CGPoint(x: controlPoint2X, y: endY + thickness / 2),
            control2: CGPoint(x: controlPoint1X, y: startY + thickness / 2)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Default Annotation View

/// Default annotation view for links
public struct SankeyDefaultAnnotation: View {
    public let context: SankeyAnnotationContext

    public init(context: SankeyAnnotationContext) {
        self.context = context
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text("\(context.sourceNode.label) → \(context.targetNode.label)")
                .font(.headline)
            Text(context.formattedValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Default Label View

/// Default label view for nodes
public struct SankeyDefaultLabel: View {
    public let context: SankeyLabelContext
    public let alignment: HorizontalAlignment

    public init(context: SankeyLabelContext, alignment: HorizontalAlignment) {
        self.context = context
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(context.node.label)
                .font(.body)
                .fontWeight(.semibold)
            Text(context.formattedValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Link View (Extracted for performance)

/// Individual link view - extracted to prevent unnecessary recomputation
private struct SankeyLinkView<Annotation: View>: View {
    let layoutLink: SankeyLayout.LayoutLink
    let labelSpace: CGFloat
    let gradientLinks: Bool
    let linkOpacity: Double
    let valueFormat: SankeyValueFormat
    let labelPosition: SankeyLabelPosition
    let isSelected: Bool
    let hasSelection: Bool
    let onTap: () -> Void
    let annotationBuilder: (SankeyAnnotationContext) -> Annotation

    // Cache the shape to avoid recreating it
    private var linkShape: SankeyLinkShape {
        SankeyLinkShape(
            startX: layoutLink.startX + (labelPosition == .outside ? labelSpace : 0),
            startY: layoutLink.startY,
            endX: layoutLink.endX + (labelPosition == .outside ? labelSpace : 0),
            endY: layoutLink.endY,
            thickness: layoutLink.thickness
        )
    }

    private var annotationContext: SankeyAnnotationContext {
        SankeyAnnotationContext(
            link: layoutLink.link,
            sourceNode: layoutLink.sourceNode,
            targetNode: layoutLink.targetNode,
            formattedValue: valueFormat.format(layoutLink.link.value)
        )
    }

    var body: some View {
        linkShape
            .fill(AnyShapeStyle(fillStyle))
            .contentShape(linkShape)
            .opacity(hasSelection ? (isSelected ? 1 : 0.2) : 1.0)
            .onTapGesture(perform: onTap)
            .overlay {
                if isSelected {
                    annotationBuilder(annotationContext)
                        .position(
                        x: (layoutLink.startX + layoutLink.endX) / 2 + labelSpace,
                        y: (layoutLink.startY + layoutLink.endY) / 2
                    )
                }
            }
    }

    private var fillStyle: AnyShapeStyle {
        if gradientLinks {
            AnyShapeStyle(LinearGradient(
                colors: [
                    layoutLink.sourceColor.opacity(linkOpacity),
                    layoutLink.targetColor.opacity(linkOpacity)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            AnyShapeStyle(layoutLink.sourceColor.opacity(linkOpacity))
        }
    }
}

// MARK: - Node View (Extracted for performance)

/// Individual node view - extracted to prevent unnecessary recomputation
private struct SankeyNodeView<Label: View>: View {
    let layoutNode: SankeyLayout.LayoutNode
    var labelSpace: CGFloat = 56
    let showLabels: Bool
    let labelPosition: SankeyLabelPosition
    let valueFormat: SankeyValueFormat
    let labelDynamicTypeSize: DynamicTypeSize?
    let hasSelection: Bool
    let labelBuilder: (SankeyLabelContext, HorizontalAlignment) -> Label

    private var isFirstColumn: Bool { layoutNode.column == 0 }
    private var isLastColumn: Bool { layoutNode.column == layoutNode.totalColumns - 1 }

    private func labelContext(value: Double) -> SankeyLabelContext {
        SankeyLabelContext(
            node: layoutNode.node,
            value: value,
            formattedValue: valueFormat.format(value),
            isFirstColumn: isFirstColumn,
            isLastColumn: isLastColumn,
            column: layoutNode.column,
            totalColumns: layoutNode.totalColumns
        )
    }

    private var shouldShowLabel: Bool {
        guard showLabels else { return false }
        switch labelPosition {
        case .inside:
            return true
        case .outside:
            return isFirstColumn || isLastColumn
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(layoutNode.node.color)
            .frame(width: layoutNode.width, height: layoutNode.height)
            .overlay(alignment: .leading) {
                if shouldShowLabel && shouldShowOnLeading && labelPosition == .inside {
                    labelBuilder(labelContext(value: isFirstColumn ? layoutNode.outgoingValue : layoutNode.incomingValue), .leading)
                        .applyDynamicTypeSize(labelDynamicTypeSize)
                        .fixedSize()
                        .opacity(hasSelection ? 0.7 : 1)
                        .padding(.leading, labelPosition == .inside ? 8 + layoutNode.width : 0)
                        .offset(x: labelPosition == .outside ? -(8 + layoutNode.width) : 0)
                }
            }
            .overlay(alignment: .trailing) {
                if shouldShowLabel && shouldShowOnTrailing && labelPosition == .inside {
                    labelBuilder(labelContext(value: layoutNode.incomingValue), .trailing)
                        .applyDynamicTypeSize(labelDynamicTypeSize)
                        .fixedSize()
                        .opacity(hasSelection ? 0.7 : 1)
                        .padding(.trailing, labelPosition == .inside ? 8 + layoutNode.width : 0)
                        .offset(x: labelPosition == .outside ? (8 + layoutNode.width) : 0)
                }
            }

            // Label Outside
            .overlay(alignment: .trailing) {
                if shouldShowLabel && shouldShowOnLeading && labelPosition == .outside {
                    labelBuilder(labelContext(value: isFirstColumn ? layoutNode.outgoingValue : layoutNode.incomingValue), .trailing)
                        .applyDynamicTypeSize(labelDynamicTypeSize)
                        .fixedSize()
                        .opacity(hasSelection ? 0.7 : 1)
                        .padding(.leading, labelPosition == .inside ? 8 + layoutNode.width : 0)
                        .offset(x: labelPosition == .outside ? -(8 + layoutNode.width) : 0)
                }
            }

            .overlay(alignment: .leading) {
                if shouldShowLabel && shouldShowOnTrailing && labelPosition == .outside {
                    labelBuilder(labelContext(value: layoutNode.incomingValue), .leading)
                        .applyDynamicTypeSize(labelDynamicTypeSize)
                        .fixedSize()
                        .opacity(hasSelection ? 0.7 : 1)
                        .padding(.trailing, labelPosition == .inside ? 8 + layoutNode.width : 0)
                        .offset(x: labelPosition == .outside ? (8 + layoutNode.width) : 0)
                }
            }
            .position(
                x: layoutNode.x + layoutNode.width / 2 + labelSpace,
                y: layoutNode.y + layoutNode.height / 2
            )
    }

    private var shouldShowOnLeading: Bool {
        switch labelPosition {
        case .inside:
            return isFirstColumn
        case .outside:
            return isFirstColumn
        }
    }

    private var shouldShowOnTrailing: Bool {
        switch labelPosition {
        case .inside:
            return !isFirstColumn
        case .outside:
            return isLastColumn
        }
    }
}

// MARK: - Sankey Diagram View

/// A SwiftUI view that renders a Sankey diagram
public struct SankeyDiagramView<LabelContent: View, AnnotationContent: View>: View {
    let data: SankeyData
    var nodeWidth: CGFloat
    var nodePadding: CGFloat
    var columnPadding: CGFloat
    var linkOpacity: Double
    var showLabels: Bool
    var labelSpace: CGFloat = 56
    var gradientLinks: Bool

    // Label position
    var labelPosition: SankeyLabelPosition

    // Label styling
    var labelFont: Font
    var labelFontWeight: Font.Weight
    var labelFontDesign: Font.Design
    var labelColor: Color

    // Value styling
    var valueFont: Font
    var valueFontWeight: Font.Weight
    var valueFontDesign: Font.Design
    var valueColor: Color
    var valueFormat: SankeyValueFormat

    // Shared dynamic type size
    var labelDynamicTypeSize: DynamicTypeSize?

    // Custom builders
    let labelBuilder: ((SankeyLabelContext, HorizontalAlignment) -> LabelContent)?
    let annotationBuilder: ((SankeyAnnotationContext) -> AnnotationContent)?

    // State for selected link popover
    @State private var selectedLinkId: UUID?

    // Internal init for custom builders
    init(
        data: SankeyData,
        nodeWidth: CGFloat,
        nodePadding: CGFloat,
        columnPadding: CGFloat,
        linkOpacity: Double,
        showLabels: Bool,
        labelSpace: CGFloat = 56,
        gradientLinks: Bool,
        labelPosition: SankeyLabelPosition,
        labelFont: Font,
        labelFontWeight: Font.Weight,
        labelFontDesign: Font.Design,
        labelColor: Color,
        valueFont: Font,
        valueFontWeight: Font.Weight,
        valueFontDesign: Font.Design,
        valueColor: Color,
        valueFormat: SankeyValueFormat,
        labelDynamicTypeSize: DynamicTypeSize?,
        labelBuilder: ((SankeyLabelContext, HorizontalAlignment) -> LabelContent)?,
        annotationBuilder: ((SankeyAnnotationContext) -> AnnotationContent)?
    ) {
        self.data = data
        self.nodeWidth = nodeWidth
        self.nodePadding = nodePadding
        self.columnPadding = columnPadding
        self.linkOpacity = linkOpacity
        self.showLabels = showLabels
        self.labelSpace = labelSpace
        self.gradientLinks = gradientLinks
        self.labelPosition = labelPosition
        self.labelFont = labelFont
        self.labelFontWeight = labelFontWeight
        self.labelFontDesign = labelFontDesign
        self.labelColor = labelColor
        self.valueFont = valueFont
        self.valueFontWeight = valueFontWeight
        self.valueFontDesign = valueFontDesign
        self.valueColor = valueColor
        self.valueFormat = valueFormat
        self.labelDynamicTypeSize = labelDynamicTypeSize
        self.labelBuilder = labelBuilder
        self.annotationBuilder = annotationBuilder
    }

    public var body: some View {
        GeometryReader { geometry in
            let diagramSize = CGSize(
                width: geometry.size.width - (labelPosition == .outside ? (labelSpace * 2) : 0),
                height: geometry.size.height
            )
            let layout = SankeyLayout(
                data: data,
                size: diagramSize,
                nodeWidth: nodeWidth,
                nodePadding: nodePadding,
                columnPadding: columnPadding
            )

            let hasSelection = selectedLinkId != nil

            ZStack(alignment: .topLeading) {
                // Draw tappable links
                ForEach(layout.links, id: \.link.id) { layoutLink in
                    
                    // Draw nodes
                    ForEach(layout.nodes, id: \.node.id) { layoutNode in
                        SankeyNodeView(
                            layoutNode: layoutNode,
                            labelSpace: labelPosition == .outside ? (labelSpace) : 0,
                            showLabels: showLabels,
                            labelPosition: labelPosition,
                            valueFormat: valueFormat,
                            labelDynamicTypeSize: labelDynamicTypeSize,
                            hasSelection: hasSelection,
                            labelBuilder: { context, alignment in
                                if let builder = labelBuilder {
                                    AnyView(builder(context, alignment))
                                } else {
                                    AnyView(defaultLabelView(context: context, alignment: alignment))
                                }
                            }
                        )
                    }
                    
                    SankeyLinkView(
                        layoutLink: layoutLink,
                        labelSpace: labelPosition == .outside ? (labelSpace) : 0,
                        gradientLinks: gradientLinks,
                        linkOpacity: linkOpacity,
                        valueFormat: valueFormat,
                        labelPosition: labelPosition,
                        isSelected: selectedLinkId == layoutLink.link.id,
                        hasSelection: hasSelection,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedLinkId == layoutLink.link.id {
                                    selectedLinkId = nil
                                } else {
                                    selectedLinkId = layoutLink.link.id
                                }
                            }
                        },
                        annotationBuilder: { context in
                            if let builder = annotationBuilder {
                                AnyView(builder(context))
                            } else {
                                AnyView(SankeyDefaultAnnotation(context: context))
                            }
                        }
                    )
                }

            }
            .drawingGroup() // Render as single Metal texture for better performance
        }
    }

    @ViewBuilder
    private func defaultLabelView(context: SankeyLabelContext, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(context.node.label)
                .font(labelFont.weight(labelFontWeight))
                .fontDesign(labelFontDesign)
                .foregroundStyle(labelColor)
            Text(context.formattedValue)
                .font(valueFont.weight(valueFontWeight))
                .fontDesign(valueFontDesign)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Convenience Initializers

public extension SankeyDiagramView where LabelContent == Never, AnnotationContent == Never {
    init(
        data: SankeyData,
        nodeWidth: CGFloat = 20,
        nodePadding: CGFloat = 10,
        columnPadding: CGFloat = 40,
        linkOpacity: Double = 0.5,
        showLabels: Bool = true,
        labelSpace: CGFloat = 56,
        gradientLinks: Bool = false,
        labelPosition: SankeyLabelPosition = .inside
    ) {
        self.data = data
        self.nodeWidth = nodeWidth
        self.nodePadding = nodePadding
        self.columnPadding = columnPadding
        self.linkOpacity = linkOpacity
        self.showLabels = showLabels
        self.labelSpace = labelSpace
        self.gradientLinks = gradientLinks
        self.labelPosition = labelPosition

        // Default label styling
        self.labelFont = .body
        self.labelFontWeight = .regular
        self.labelFontDesign = .default
        self.labelColor = .primary

        // Default value styling
        self.valueFont = .subheadline
        self.valueFontWeight = .regular
        self.valueFontDesign = .default
        self.valueColor = .secondary
        self.valueFormat = .integer

        self.labelDynamicTypeSize = nil

        self.labelBuilder = nil
        self.annotationBuilder = nil
    }
}

// MARK: - View Modifiers

public extension SankeyDiagramView {
    /// Sets the width of the node bars
    func nodeWidth(_ width: CGFloat) -> SankeyDiagramView {
        var view = self
        view.nodeWidth = width
        return view
    }

    /// Sets the vertical padding between nodes in the same column
    func nodePadding(_ padding: CGFloat) -> SankeyDiagramView {
        var view = self
        view.nodePadding = padding
        return view
    }

    /// Sets the horizontal padding between columns
    func columnPadding(_ padding: CGFloat) -> SankeyDiagramView {
        var view = self
        view.columnPadding = padding
        return view
    }

    /// Sets the opacity of the link flows
    func linkOpacity(_ opacity: Double) -> SankeyDiagramView {
        var view = self
        view.linkOpacity = opacity
        return view
    }

    /// Shows or hides the node labels
    func showLabels(_ show: Bool) -> SankeyDiagramView {
        var view = self
        view.showLabels = show
        return view
    }

    /// Enables gradient coloring for links from source to target color
    func gradientLinks(_ enabled: Bool) -> SankeyDiagramView {
        var view = self
        view.gradientLinks = enabled
        return view
    }

    /// Sets the label position (inside or outside the diagram)
    func labelPosition(_ position: SankeyLabelPosition) -> SankeyDiagramView {
        var view = self
        view.labelPosition = position
        return view
    }

    // MARK: - Label Styling

    /// Sets the font for node labels
    func labelFont(_ font: Font) -> SankeyDiagramView {
        var view = self
        view.labelFont = font
        return view
    }

    /// Sets the font weight for node labels
    func labelFontWeight(_ weight: Font.Weight) -> SankeyDiagramView {
        var view = self
        view.labelFontWeight = weight
        return view
    }

    /// Sets the font design for node labels
    func labelFontDesign(_ design: Font.Design) -> SankeyDiagramView {
        var view = self
        view.labelFontDesign = design
        return view
    }

    /// Sets the color for node labels
    func labelColor(_ color: Color) -> SankeyDiagramView {
        var view = self
        view.labelColor = color
        return view
    }

    // MARK: - Value Styling

    /// Sets the font for value labels
    func valueFont(_ font: Font) -> SankeyDiagramView {
        var view = self
        view.valueFont = font
        return view
    }

    /// Sets the font weight for value labels
    func valueFontWeight(_ weight: Font.Weight) -> SankeyDiagramView {
        var view = self
        view.valueFontWeight = weight
        return view
    }

    /// Sets the font design for value labels
    func valueFontDesign(_ design: Font.Design) -> SankeyDiagramView {
        var view = self
        view.valueFontDesign = design
        return view
    }

    /// Sets the color for value labels
    func valueColor(_ color: Color) -> SankeyDiagramView {
        var view = self
        view.valueColor = color
        return view
    }

    /// Sets the format for value labels
    func valueFormat(_ format: SankeyValueFormat) -> SankeyDiagramView {
        var view = self
        view.valueFormat = format
        return view
    }

    // MARK: - Shared Styling

    /// Sets the dynamic type size for both labels and values
    func labelDynamicTypeSize(_ size: DynamicTypeSize) -> SankeyDiagramView {
        var view = self
        view.labelDynamicTypeSize = size
        return view
    }
}

// MARK: - Custom View Builder Modifiers

public extension SankeyDiagramView where LabelContent == Never, AnnotationContent == Never {
    /// Provides a custom view builder for node labels
    func customLabel<NewLabel: View>(
        @ViewBuilder _ builder: @escaping (SankeyLabelContext, HorizontalAlignment) -> NewLabel
    ) -> SankeyDiagramView<NewLabel, Never> {
        SankeyDiagramView<NewLabel, Never>(
            data: data,
            nodeWidth: nodeWidth,
            nodePadding: nodePadding,
            columnPadding: columnPadding,
            linkOpacity: linkOpacity,
            showLabels: showLabels,
            labelSpace: labelSpace,
            gradientLinks: gradientLinks,
            labelPosition: labelPosition,
            labelFont: labelFont,
            labelFontWeight: labelFontWeight,
            labelFontDesign: labelFontDesign,
            labelColor: labelColor,
            valueFont: valueFont,
            valueFontWeight: valueFontWeight,
            valueFontDesign: valueFontDesign,
            valueColor: valueColor,
            valueFormat: valueFormat,
            labelDynamicTypeSize: labelDynamicTypeSize,
            labelBuilder: builder,
            annotationBuilder: nil
        )
    }

    /// Provides a custom view builder for link annotations
    func customAnnotation<NewAnnotation: View>(
        @ViewBuilder _ builder: @escaping (SankeyAnnotationContext) -> NewAnnotation
    ) -> SankeyDiagramView<Never, NewAnnotation> {
        SankeyDiagramView<Never, NewAnnotation>(
            data: data,
            nodeWidth: nodeWidth,
            nodePadding: nodePadding,
            columnPadding: columnPadding,
            linkOpacity: linkOpacity,
            showLabels: showLabels,
            labelSpace: labelSpace,
            gradientLinks: gradientLinks,
            labelPosition: labelPosition,
            labelFont: labelFont,
            labelFontWeight: labelFontWeight,
            labelFontDesign: labelFontDesign,
            labelColor: labelColor,
            valueFont: valueFont,
            valueFontWeight: valueFontWeight,
            valueFontDesign: valueFontDesign,
            valueColor: valueColor,
            valueFormat: valueFormat,
            labelDynamicTypeSize: labelDynamicTypeSize,
            labelBuilder: nil,
            annotationBuilder: builder
        )
    }
}

public extension SankeyDiagramView where LabelContent == Never {
    /// Provides a custom view builder for node labels (when annotation is already customized)
    func customLabel<NewLabel: View>(
        @ViewBuilder _ builder: @escaping (SankeyLabelContext, HorizontalAlignment) -> NewLabel
    ) -> SankeyDiagramView<NewLabel, AnnotationContent> {
        SankeyDiagramView<NewLabel, AnnotationContent>(
            data: data,
            nodeWidth: nodeWidth,
            nodePadding: nodePadding,
            columnPadding: columnPadding,
            linkOpacity: linkOpacity,
            showLabels: showLabels,
            labelSpace: labelSpace,
            gradientLinks: gradientLinks,
            labelPosition: labelPosition,
            labelFont: labelFont,
            labelFontWeight: labelFontWeight,
            labelFontDesign: labelFontDesign,
            labelColor: labelColor,
            valueFont: valueFont,
            valueFontWeight: valueFontWeight,
            valueFontDesign: valueFontDesign,
            valueColor: valueColor,
            valueFormat: valueFormat,
            labelDynamicTypeSize: labelDynamicTypeSize,
            labelBuilder: builder,
            annotationBuilder: annotationBuilder
        )
    }
}

public extension SankeyDiagramView where AnnotationContent == Never {
    /// Provides a custom view builder for link annotations (when label is already customized)
    func customAnnotation<NewAnnotation: View>(
        @ViewBuilder _ builder: @escaping (SankeyAnnotationContext) -> NewAnnotation
    ) -> SankeyDiagramView<LabelContent, NewAnnotation> {
        SankeyDiagramView<LabelContent, NewAnnotation>(
            data: data,
            nodeWidth: nodeWidth,
            nodePadding: nodePadding,
            columnPadding: columnPadding,
            linkOpacity: linkOpacity,
            showLabels: showLabels,
            labelSpace: labelSpace,
            gradientLinks: gradientLinks,
            labelPosition: labelPosition,
            labelFont: labelFont,
            labelFontWeight: labelFontWeight,
            labelFontDesign: labelFontDesign,
            labelColor: labelColor,
            valueFont: valueFont,
            valueFontWeight: valueFontWeight,
            valueFontDesign: valueFontDesign,
            valueColor: valueColor,
            valueFormat: valueFormat,
            labelDynamicTypeSize: labelDynamicTypeSize,
            labelBuilder: labelBuilder,
            annotationBuilder: builder
        )
    }
}
