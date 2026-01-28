# SankeySwift

A native SwiftUI Sankey diagram library for iOS, macOS, tvOS, watchOS, and visionOS.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20tvOS%2017%20%7C%20watchOS%2010%20%7C%20visionOS%201-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- Native SwiftUI implementation with smooth animations
- Multi-column support with automatic topological sorting
- Gradient link coloring from source to target
- Tappable links with customizable annotations
- Flexible label positioning (inside or outside the diagram)
- Customizable fonts, colors, and value formatting
- Automatic merging of duplicate links
- High performance with Metal-accelerated rendering

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/tyodsgn/SankeySwift.git", from: "1.0.0")
]
```

Or add it directly in Xcode via **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import SwiftUI
import SankeySwift

struct ContentView: View {
    let data = SankeyData(
        nodes: [
            SankeyNode("Revenue", color: .green),
            SankeyNode("Expenses", color: .red),
            SankeyNode("Profit", color: .blue),
        ],
        links: [
            SankeyLink(100, from: "Revenue", to: "Expenses"),
            SankeyLink(50, from: "Revenue", to: "Profit"),
        ]
    )

    var body: some View {
        SankeyDiagramView(data: data)
            .padding()
    }
}
```

## Usage

### Creating Nodes and Links

```swift
// Create nodes with custom colors and labels
let nodes = [
    SankeyNode("source1", color: .blue),
    SankeyNode("source2", color: .purple, label: "Custom Label"),
    SankeyNode("target", color: .green),
]

// Create links with values (and optional custom color)
let links = [
    SankeyLink(100, from: "source1", to: "target"),
    SankeyLink(50, from: "source2", to: "target", color: .orange),
]

// Create data container (automatically merges duplicate links)
let data = SankeyData(nodes: nodes, links: links)

// Or disable auto-merging
let dataNoMerge = SankeyData(nodes: nodes, links: links, mergeLinks: false)
```

### Basic Configuration

```swift
SankeyDiagramView(
    data: data,
    nodeWidth: 20,           // Width of node bars
    nodePadding: 10,         // Vertical spacing between nodes
    columnPadding: 40,       // Horizontal spacing between columns
    linkOpacity: 0.5,        // Opacity of link flows
    showLabels: true,        // Show/hide labels
    gradientLinks: true,     // Enable gradient coloring
    labelPosition: .inside   // .inside or .outside
)
```

### Styling with Modifiers

```swift
SankeyDiagramView(data: data)
    // Layout
    .nodeWidth(12)
    .nodePadding(8)
    .columnPadding(60)
    .linkOpacity(0.6)
    .gradientLinks(true)

    // Label styling
    .labelFont(.body)
    .labelFontWeight(.semibold)
    .labelFontDesign(.rounded)
    .labelColor(.primary)

    // Value styling
    .valueFont(.caption)
    .valueFontWeight(.regular)
    .valueFontDesign(.monospaced)
    .valueColor(.secondary)

    // Value formatting
    .valueFormat(.integer)  // or use custom formatter
```

### Label Positioning

```swift
// Labels inside the diagram (default)
SankeyDiagramView(data: data)
    .labelPosition(.inside)

// Labels outside - first column on left, last on right
SankeyDiagramView(data: data)
    .labelPosition(.outside)
```

### Custom Value Formatting

```swift
// Integer format (default)
.valueFormat(.integer)

// Currency
.valueFormat(.custom { value in
    value.formatted(.currency(code: "USD"))
})

// Percentage
.valueFormat(.custom { value in
    "\(Int(value))%"
})

// Custom format
.valueFormat(.custom { value in
    String(format: "%.2f units", value)
})
```

### Custom Label View

```swift
SankeyDiagramView(data: data)
    .customLabel { context, alignment in
        HStack(spacing: 4) {
            Circle()
                .fill(context.node.color)
                .frame(width: 8, height: 8)
            VStack(alignment: alignment, spacing: 0) {
                Text(context.node.label)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(context.formattedValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
```

The `SankeyLabelContext` provides:
- `node`: The SankeyNode
- `value`: Raw numeric value
- `formattedValue`: Value formatted according to `valueFormat`
- `isFirstColumn` / `isLastColumn`: Position information
- `column` / `totalColumns`: Column index and total count

### Custom Annotation View

```swift
SankeyDiagramView(data: data)
    .customAnnotation { context in
        VStack(spacing: 8) {
            HStack {
                Circle().fill(context.sourceNode.color).frame(width: 12, height: 12)
                Text("→")
                Circle().fill(context.targetNode.color).frame(width: 12, height: 12)
            }
            Text(context.formattedValue)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
```

The `SankeyAnnotationContext` provides:
- `link`: The SankeyLink
- `sourceNode` / `targetNode`: Connected nodes
- `formattedValue`: Value formatted according to `valueFormat`

### Multi-Column Diagrams

The library automatically handles multi-column diagrams using topological sorting:

```swift
let data = SankeyData(
    nodes: [
        // Source column
        SankeyNode("A", color: .blue),
        SankeyNode("B", color: .purple),
        // Middle column
        SankeyNode("X", color: .red),
        SankeyNode("Y", color: .yellow),
        // Destination column
        SankeyNode("Final", color: .green),
    ],
    links: [
        // A/B → X/Y
        SankeyLink(10, from: "A", to: "X"),
        SankeyLink(5, from: "A", to: "Y"),
        SankeyLink(8, from: "B", to: "X"),
        SankeyLink(12, from: "B", to: "Y"),
        // X/Y → Final
        SankeyLink(18, from: "X", to: "Final"),
        SankeyLink(17, from: "Y", to: "Final"),
    ]
)
```

## Requirements

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 10.0+
- visionOS 1.0+
- Swift 5.9+

## License

MIT License. See [LICENSE](LICENSE) for details.
