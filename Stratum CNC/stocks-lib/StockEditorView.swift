//
//  StockEditorView.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 25.08.2026.
//

import SwiftUI

struct StockEditorView: View {

    /// The saved stock. Nothing is written until the user taps Save.
    let stock: StockMaterial
    let onSave: (StockMaterial) -> Void

    @State private var draft: StockMaterial

    @Environment(\.openURL) private var openURL

    init(stock: StockMaterial, onSave: @escaping (StockMaterial) -> Void) {
        self.stock = stock
        self.onSave = onSave
        _draft = State(initialValue: stock)
    }

    private var hasChanges: Bool {
        draft != stock
    }

    var body: some View {
        Form {
            geometrySection
            generalSection
        }
        .formStyle(.grouped)
        .navigationTitle(stock.name)
        .safeAreaInset(edge: .bottom) {
            if hasChanges {
                HStack {
                    Text("Unsaved changes")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Revert") {
                        draft = stock
                    }
                    Button("Save") {
                        onSave(draft)
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }
}

private extension StockEditorView {

    var generalSection: some View {
        Section("Material") {
            TextField("Name", text: $draft.name)

            Picker("Material", selection: $draft.material) {
                ForEach(StockMaterialType.allCases, id: \.self) { material in
                    Text(material.displayName)
                        .tag(material)
                }
            }

            Stepper(value: $draft.quantity, in: 0...9999) {
                HStack {
                    Text("In stock")
                    Spacer()
                    TextField("In stock", value: $draft.quantity, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }

            HStack {
                TextField("Link", text: linkBinding)
                Button {
                    if let url = draft.linkURL {
                        openURL(url)
                    }
                } label: {
                    Label("Buy", systemImage: "cart")
                }
                .disabled(draft.linkURL == nil)
            }
        }
    }

    var linkBinding: Binding<String> {
        Binding(
            get: { draft.link ?? "" },
            set: { draft.link = $0.isEmpty ? nil : $0 }
        )
    }
}

private extension StockEditorView {

    var geometrySection: some View {
        Section("Geometry") {
            GeometryReader { proxy in
              HStack(alignment: .top, spacing: 16) {
                // Nested Form, same as the tools editor, so rows get the same
                // label/value alignment and text field styling.
                Form {
                    Picker("Shape", selection: geometryKindBinding) {
                        ForEach(StockGeometry.Kind.allCases) { kind in
                            Text(kind.displayName)
                                .tag(kind)
                        }
                    }
                    .frame(minWidth: 100, maxWidth: 180)

                    geometryFields
                }
                .scrollDisabled(true)
                // About a third of the box, but never narrower than the fields need.
                .frame(width: max(proxy.size.width / 3, 300))

                Divider()

                StockPreviewView(geometry: draft.geometry, material: draft.material)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
              }
            }
            .frame(height: 240)
            .padding(.vertical, 4)
        }
    }

    var geometryKindBinding: Binding<StockGeometry.Kind> {
        Binding(
            get: {
                draft.geometry.kind
            },
            set: { newKind in
                draft.geometry = draft.geometry.converted(to: newKind)
            }
        )
    }
}

private extension StockEditorView {

    @ViewBuilder
    var geometryFields: some View {

        switch draft.geometry {

        case .rectangular(let width, let height, let depth):
            MeasurementField(
                title: "Width",
                value: Binding(
                    get: { width },
                    set: {
                        draft.geometry = .rectangular(
                            width: $0,
                            height: height,
                            depth: depth
                        )
                    }
                ),
                unit: "mm"
            )

            MeasurementField(
                title: "Height",
                value: Binding(
                    get: { height },
                    set: {
                        draft.geometry = .rectangular(
                            width: width,
                            height: $0,
                            depth: depth
                        )
                    }
                ),
                unit: "mm"
            )

            MeasurementField(
                title: "Depth",
                value: Binding(
                    get: { depth },
                    set: {
                        draft.geometry = .rectangular(
                            width: width,
                            height: height,
                            depth: $0
                        )
                    }
                ),
                unit: "mm"
            )

        case .cylindrical(let diameter, let length):
            MeasurementField(
                title: "Diameter",
                value: Binding(
                    get: { diameter },
                    set: {
                        draft.geometry = .cylindrical(
                            diameter: $0,
                            length: length
                        )
                    }
                ),
                unit: "mm"
            )

            MeasurementField(
                title: "Length",
                value: Binding(
                    get: { length },
                    set: {
                        draft.geometry = .cylindrical(
                            diameter: diameter,
                            length: $0
                        )
                    }
                ),
                unit: "mm"
            )

        case .disk(let outerDiameter, let innerDiameter, let depth):
            MeasurementField(
                title: "Outer Diameter",
                value: Binding(
                    get: { outerDiameter },
                    set: {
                        draft.geometry = .disk(outerDiameter: $0, innerDiameter: innerDiameter, depth: depth)
                    }
                ),
                unit: "mm"
            )

            MeasurementField(
                title: "Inner Diameter",
                value: Binding(
                    get: { innerDiameter },
                    set: {
                        draft.geometry = .disk(outerDiameter: outerDiameter, innerDiameter: $0, depth: depth)
                    }
                ),
                unit: "mm"
            )

            MeasurementField(
                title: "Depth",
                value: Binding(
                    get: { depth },
                    set: {
                        draft.geometry = .disk(outerDiameter: outerDiameter, innerDiameter: innerDiameter, depth: $0)
                    }
                ),
                unit: "mm"
            )
        }
    }
}
