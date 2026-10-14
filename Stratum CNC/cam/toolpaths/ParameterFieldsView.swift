//
//  ParameterFieldsView.swift
//  Stratum CNC
//
//  Renders a `[SC.ParameterField]` -- the form that `SC.MachiningOperation.formFields`
//  builds for whichever operation is chosen -- with the app's own controls
//  (`NumberField`, `IntField`, `ToggleField`). Nothing here knows about a specific
//  operation: what appears, in which order and with which range is decided entirely by
//  the fields it is given, so a new operation or parameter in `formFields` shows up
//  without touching any view code.
//

import SwiftUI
import StratumCAM

struct ParameterFieldsView: View {
    let fields: [SC.ParameterField]

    /// Compact/expanded toggle. It only changes the cut-direction choice, which is drawn by
    /// `DirectionPicker` (glyph button + popover when compact, glyph tiles laid out inline
    /// when expanded); every other choice stays the native pull-down menu in both modes.
    var expanded: Bool = false

    /// Field ids the app doesn't offer (yet). Matched at every nesting depth.
    var hiddenFieldIDs: Set<String> = []

    /// Variant case ids the app doesn't offer (yet), e.g. an engine path that isn't implemented.
    var hiddenCaseIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block {
                case .leaves(_, let leaves):
                    // Simple values flow side by side, wrapping when the panel is narrow.
                    // Cells are top-leading, not top-centred: a control that hugs its content
                    // (the direction button) would otherwise float in the middle of a wide cell.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .topLeading)],
                              alignment: .leading,
                              spacing: 8) {
                        ForEach(leaves) { leaf in
                            leafView(leaf)
                        }
                    }
                case .field(let field):
                    blockView(field)
                }
            }
        }
    }

    // MARK: Layout

    private enum Block: Identifiable {
        case leaves(id: String, [SC.ParameterField])
        case field(SC.ParameterField)

        var id: String {
            switch self {
                case .leaves(let id, _): return "leaves.\(id)"
                case .field(let field): return field.id
            }
        }
    }

    /// Consecutive simple fields are grouped into one wrapping grid; everything that carries
    /// nested fields (variants, groups, lists) gets a full-width block of its own.
    private var blocks: [Block] {
        var result: [Block] = []
        var run: [SC.ParameterField] = []

        func flush() {
            if let first = run.first {
                result.append(.leaves(id: first.id, run))
                run = []
            }
        }

        for field in fields where !hiddenFieldIDs.contains(field.id) {
            if isLeaf(field) {
                run.append(field)
            } else {
                flush()
                result.append(.field(field))
            }
        }
        flush()
        return result
    }

    private func isLeaf(_ field: SC.ParameterField) -> Bool {
        switch field {
            case .choice(let f):
                // Expanded, the direction tiles need their full width, so that choice gets
                // a block of its own instead of a cell in the wrapping grid.
                return !(expanded && f.isCutDirection)
            case .double, .int, .bool:
                return true
            default:
                return false
        }
    }

    // MARK: Simple fields

    @ViewBuilder
    private func leafView(_ field: SC.ParameterField) -> some View {
        switch field {
            case .double(let f):
                NumberField(title: f.label.uppercased(),
                            value: Binding(get: { f.value },
                                           set: { f.onChange(clamp($0, to: f.range)) }),
                            suffix: f.unit ?? "")
            case .int(let f):
                IntField(title: f.label.uppercased(),
                         value: Binding(get: { f.value },
                                        set: { f.onChange(clamp($0, to: f.range)) }),
                         suffix: "")
            case .bool(let f):
                ToggleField(title: f.label.uppercased(),
                            isOn: Binding(get: { f.value }, set: { f.onChange($0) }))
            case .choice(let f) where f.isCutDirection:
                // Climb / conventional: same glyph picker as the contour side.
                DirectionPicker(direction: Binding(get: { f.cutDirection },
                                                   set: { f.onChange($0.fieldID) }),
                                expanded: expanded)
            case .choice(let f):
                ChoiceControl(title: f.label.uppercased(),
                              options: f.options,
                              selectedID: f.selectedId,
                              expanded: expanded,
                              onSelect: f.onChange)
            default:
                EmptyView()
        }
    }

    // MARK: Fields with content of their own

    @ViewBuilder
    private func blockView(_ field: SC.ParameterField) -> some View {
        switch field {

            case .choice:
                leafView(field)

            case .optionalDouble(let f):
                // Same look as the old PECKING / DWELL rows: a switch, and the value once it's on.
                HStack(spacing: 8) {
                    ToggleField(title: f.label.uppercased(),
                                isOn: Binding(get: { f.value != nil },
                                              set: { f.onChange($0 ? f.defaultValueWhenEnabled : nil) }))
                    if let value = f.value {
                        NumberField(title: "\(f.label.uppercased()) VALUE",
                                    value: Binding(get: { value },
                                                   set: { f.onChange(clamp($0, to: f.range)) }),
                                    suffix: f.unit ?? "")
                    }
                }

            case .variant(let f):
                let visibleCases = f.cases.filter { !hiddenCaseIDs.contains($0.id) }
                VStack(alignment: .leading, spacing: 8) {
                    ChoiceControl(title: f.label.uppercased(),
                                  options: visibleCases.map { .init(id: $0.id, label: $0.label) },
                                  selectedID: f.selectedId,
                                  expanded: expanded,
                                  onSelect: f.onSelect)
                    if let selected = f.cases.first(where: { $0.id == f.selectedId }), !selected.fields.isEmpty {
                        nested(selected.fields)
                    }
                }

            case .group(let f):
                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle(f.label)
                    nested(f.fields)
                }

            case .optionalGroup(let f):
                VStack(alignment: .leading, spacing: 8) {
                    ToggleField(title: f.label.uppercased(),
                                isOn: Binding(get: { f.isPresent }, set: { f.onToggle($0) }))
                    if f.isPresent {
                        nested(f.fields)
                    }
                }

            case .row(let f):
                // Unlike the wrapping "leaves" grid, this HStack never wraps --
                // the fields it holds (e.g. diameter + pitch) always sit on one row.
                HStack(alignment: .top, spacing: 8) {
                    ForEach(f.fields) { field in
                        leafView(field)
                    }
                }

            case .list(let f):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionTitle(f.label)
                        Spacer()
                        Button {
                            f.onAdd()
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    ForEach(f.items) { item in
                        HStack(alignment: .top, spacing: 8) {
                            nested(item.fields)
                            Button {
                                f.onRemove(item.id)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)
                        }
                    }
                }

            default:
                leafView(field)
        }
    }

    private func nested(_ fields: [SC.ParameterField]) -> some View {
        ParameterFieldsView(fields: fields,
                            expanded: expanded,
                            hiddenFieldIDs: hiddenFieldIDs,
                            hiddenCaseIDs: hiddenCaseIDs)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 2)
            }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9))
    }

    // MARK: Helpers

    /// The ranges in `formFields` are the limits the engine accepts, so a typed value is
    /// pulled back inside them instead of being passed on.
    private func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Cut direction

private extension SC.ParameterField.ChoiceField {

    /// True for the climb / conventional choice built by `SC.cutDirectionChoice`. Matched on
    /// its options rather than its id, so every operation's direction field -- contour,
    /// pocket, facing, counterbore, chamfer -- gets the glyph picker, while thread
    /// handedness and spiral direction keep the plain menu.
    var isCutDirection: Bool {
        options.map(\.id) == [SC.CutDirection.climb.rawValue, SC.CutDirection.conventional.rawValue]
    }

    var cutDirection: CutDirectionOption {
        selectedId == SC.CutDirection.conventional.rawValue ? .conventional : .climb
    }
}

private extension CutDirectionOption {
    var fieldID: String {
        switch self {
            case .climb:        return SC.CutDirection.climb.rawValue
            case .conventional: return SC.CutDirection.conventional.rawValue
        }
    }
}

// MARK: - Choice

/// A titled choice between string-identified options, styled as a native macOS pull-down
/// menu at all times (same look as `ToolPicker`'s) -- never as a row of pills. The cut
/// direction is the exception: see `DirectionPicker`.
struct ChoiceControl: View {
    let title: String
    let options: [SC.ParameterField.ChoiceField.Option]
    let selectedID: String
    var expanded: Bool = false
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9))

            Menu {
                ForEach(options) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        if option.id == selectedID {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedLabel)
                        .fontWeight(.semibold)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private var selectedLabel: String {
        options.first(where: { $0.id == selectedID })?.label ?? ""
    }
}
