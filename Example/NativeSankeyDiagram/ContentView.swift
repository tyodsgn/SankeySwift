//
//  ContentView.swift
//  NativeSankeyDiagram
//
//  Created by Setyono Dwi Utomo on 27/01/26.
//

import SwiftUI
import SankeySwift

struct ContentView: View {
    // Example with 3 columns: Sources → Middle → Destinations
    let data = SankeyData(
        nodes: [
            // Column 1 - Sources
            SankeyNode("A", color: .blue),
            SankeyNode("B", color: .purple),
            // Column 2 - Middle
            SankeyNode("X", color: .red),
            SankeyNode("Y", color: .yellow),
            SankeyNode("Z", color: .green),
            // Column 3 - Destinations
            SankeyNode("Final1", color: .orange),
            SankeyNode("Final2", color: .cyan),
        ],
        links: [
            // A/B → X/Y/Z
            SankeyLink(5, from: "A", to: "X"),
            SankeyLink(7, from: "A", to: "Y"),
            SankeyLink(6, from: "A", to: "Z"),
            SankeyLink(2, from: "B", to: "X"),
            SankeyLink(9, from: "B", to: "Y"),
            SankeyLink(4, from: "B", to: "Z"),
            // X/Y/Z → Final1/Final2
            
            SankeyLink(4, from: "X", to: "Final1"),
            SankeyLink(3, from: "X", to: "Final2"),
            SankeyLink(10, from: "Y", to: "Final1"),
            SankeyLink(6, from: "Y", to: "Final2"),
            SankeyLink(5, from: "Z", to: "Final1"),
            SankeyLink(5, from: "Z", to: "Final2"),
        ]
    )

    @State private var numberOfColumns: Int = 0

    var body: some View {
        VStack {
            Text("Sankey Diagram")
                .font(.headline)
                .padding(.top)

            Text("Number of columns: \(numberOfColumns)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SankeyDiagramView(data: data,
                              nodeWidth: 8,
                              gradientLinks: true)
            .valueFormat(.custom({ amount in
                amount.formatted(.currency(code: "USD"))
            }))
            .columnCount($numberOfColumns)

                .padding()
        }
    }
}

#Preview("Inside Labels") {
    ContentView()
}

#Preview("Outside Labels") {
    let data = SankeyData(
        nodes: [
            SankeyNode("Source A", color: .blue),
            SankeyNode("Source B", color: .purple),
            SankeyNode("Middle X", color: .red),
            SankeyNode("Middle Y", color: .yellow),
            SankeyNode("End 1", color: .orange),
            SankeyNode("End 2", color: .cyan),
        ],
        links: [
            SankeyLink(5, from: "Source A", to: "Middle X"),
            SankeyLink(7, from: "Source A", to: "Middle Y"),
            SankeyLink(2, from: "Source B", to: "Middle X"),
            SankeyLink(9, from: "Source B", to: "Middle Y"),
            SankeyLink(4, from: "Middle X", to: "End 1"),
            SankeyLink(3, from: "Middle X", to: "End 2"),
            SankeyLink(10, from: "Middle Y", to: "End 1"),
            SankeyLink(6, from: "Middle Y", to: "End 2"),
        ]
    )

    return SankeyDiagramView(data: data, nodeWidth: 8, gradientLinks: true)
        .labelFont(.body)
        .labelFontWeight(.semibold)
        .valueFont(.caption)
        .labelPosition(.outside)
        .padding()
}

#Preview("Custom Label") {
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

    return SankeyDiagramView(data: data, nodeWidth: 10, gradientLinks: true)
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
        .padding()
}

#Preview("Custom Annotation") {
    let data = SankeyData(
        nodes: [
            SankeyNode("A", color: .blue),
            SankeyNode("B", color: .green),
        ],
        links: [
            SankeyLink(50, from: "A", to: "B"),
        ]
    )

    return SankeyDiagramView(data: data, nodeWidth: 12, gradientLinks: true)
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
        .padding()
}

#Preview("Column Count with ScrollView") {
    struct ScrollableExample: View {
        let data = SankeyData(
            nodes: [
                SankeyNode("Source A", color: .blue),
                SankeyNode("Source B", color: .purple),
                SankeyNode("Middle X", color: .red),
                SankeyNode("Middle Y", color: .yellow),
                SankeyNode("Middle Z", color: .green),
                SankeyNode("Step 1", color: .orange),
                SankeyNode("Step 2", color: .cyan),
                SankeyNode("End 1", color: .pink),
                SankeyNode("End 2", color: .mint),
            ],
            links: [
                SankeyLink(5, from: "Source A", to: "Middle X"),
                SankeyLink(7, from: "Source A", to: "Middle Y"),
                SankeyLink(2, from: "Source B", to: "Middle X"),
                SankeyLink(9, from: "Source B", to: "Middle Z"),
                SankeyLink(4, from: "Middle X", to: "Step 1"),
                SankeyLink(3, from: "Middle Y", to: "Step 1"),
                SankeyLink(5, from: "Middle Z", to: "Step 2"),
                SankeyLink(6, from: "Step 1", to: "End 1"),
                SankeyLink(8, from: "Step 2", to: "End 2"),
            ]
        )

        @State private var columnCount: Int = 0

        var body: some View {
            VStack(spacing: 16) {
                Text("Adaptive ScrollView Example")
                    .font(.headline)

                Text("Columns: \(columnCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(columnCount > 2 ? "Scroll enabled (>2 columns)" : "Scroll disabled (≤2 columns)")
                    .font(.caption)
                    .foregroundStyle(columnCount > 2 ? .green : .orange)
                
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.purple, .green], startPoint: .leading, endPoint: .trailing)
                            .opacity(1)
                    )
                Group {
                    ScrollView(.horizontal, showsIndicators: true) {
                        SankeyDiagramView(data: data,
                                          nodeWidth: 8,
                                          linkOpacity: 0.5,
                                          gradientLinks: true)
                            .columnCount($columnCount)
                            .frame(minWidth: columnCount > 2 ? nil : 1000)
                            .onAppear{
                                print("columnCount: \(columnCount)")
                            }
                    }
                }
            }
            .padding()
        }
    }

    return ScrollableExample()
}
