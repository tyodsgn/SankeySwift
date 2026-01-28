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
//            SankeyLink(4, from: "X", to: "Final1"),
//            SankeyLink(3, from: "X", to: "Final2"),
            SankeyLink(10, from: "Y", to: "Final1"),
            SankeyLink(6, from: "Y", to: "Final2"),
            SankeyLink(5, from: "Z", to: "Final1"),
            SankeyLink(5, from: "Z", to: "Final2"),
        ]
    )

    var body: some View {
        VStack {
            Text("Sankey Diagram")
                .font(.headline)
                .padding(.top)

            SankeyDiagramView(data: data,
                              nodeWidth: 8,
                              gradientLinks: true)
            .labelPosition(.outside)
            .valueFormat(.custom({ amount in
                amount.formatted(.currency(code: "USD"))
            }))
            
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
