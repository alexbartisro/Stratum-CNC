//
//  StockListView.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 25.08.2026.
//

import SwiftUI

struct StockListView: View {

    let stocks: [StockMaterial]
    @Binding var selectedStockID: StockMaterial.ID?
    @Binding var inStockOnly: Bool
    let onDuplicate: (StockMaterial) -> Void
    let onDelete: (StockMaterial) -> Void

    var body: some View {
        List(selection: $selectedStockID) {
            ForEach(stocks.groupedByMaterial) { group in
                Section(group.material.displayName) {
                    ForEach(group.stocks) { stock in
                        HStack(spacing: 10) {
                            StockPreviewView(geometry: stock.geometry, material: stock.material)
                                .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(stock.name)
                                Text(stock.geometry.dimensionsDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Text("\(stock.quantity)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(stock.quantity == 0 ? .tertiary : .secondary)
                        }
                        .tag(stock.id)
                        .contextMenu {
                            Button {
                                onDuplicate(stock)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }

                            Divider()

                            Button(role: .destructive) {
                                onDelete(stock)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if stocks.isEmpty {
                ContentUnavailableView(
                    "No Stock",
                    systemImage: "tray",
                    description: Text("No materials have a quantity set.")
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                Toggle("In stock only", isOn: $inStockOnly)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.bar)
        }
        .navigationTitle("Stock Library")
    }
}
