//
//  CalendarOverlayEditorView.swift
//  Tempo
//

import SwiftUI

struct CalendarOverlayEditorView: View {
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(WorkCalendarStore.self) private var calendarStore

    @Binding var overlay: CalendarOverlay

    private var sourceCalendar: WorkCalendar? {
        calendarStore.calendar(id: overlay.sourceCalendarID)
    }

    private var sourceShiftTypes: [ShiftTypeDefinition] {
        guard let source = sourceCalendar else { return [] }
        return source.overlaySourceShiftTypeIDs.compactMap { shiftTypeStore.shiftType(id: $0) }
    }

    var body: some View {
        Form {
            if let source = sourceCalendar {
                Section("Origen") {
                    Text(source.listDisplayName)
                        .font(.headline.weight(.semibold))
                }
            }

            Section {
                if sourceShiftTypes.isEmpty {
                    Text("Este calendario no tiene turnos definidos.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sourceShiftTypes) { shiftType in
                        shiftConfigurationRow(shiftType)
                    }
                }
            } header: {
                Text("Turnos superpuestos")
            } footer: {
                Text("Elige qué turnos se muestran y personaliza color y texto de la burbuja.")
            }
        }
        .navigationTitle("Superposición")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shiftConfigurationRow(_ shiftType: ShiftTypeDefinition) -> some View {
        let isIncluded = overlay.includes(shiftTypeID: shiftType.id)
        return VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: inclusionBinding(for: shiftType)) {
                Text(shiftType.name)
                    .font(.body.weight(.semibold))
            }

            if isIncluded {
                HStack {
                    Text("Texto")
                        .foregroundStyle(.secondary)
                    TextField("Ej. V", text: labelBinding(for: shiftType.id))
                        .multilineTextAlignment(.trailing)
                }

                Text("Color de burbuja")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(ShiftTypeColorOption.allCases) { option in
                        overlayColorSwatch(option, shiftTypeID: shiftType.id)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func inclusionBinding(for shiftType: ShiftTypeDefinition) -> Binding<Bool> {
        Binding(
            get: { overlay.includes(shiftTypeID: shiftType.id) },
            set: { isOn in
                if isOn {
                    if !overlay.includedShiftTypeIDs.contains(shiftType.id) {
                        overlay.includedShiftTypeIDs.append(shiftType.id)
                    }
                    overlay.ensureAppearance(for: shiftType)
                } else {
                    overlay.includedShiftTypeIDs.removeAll { $0 == shiftType.id }
                }
            }
        )
    }

    private func labelBinding(for shiftTypeID: UUID) -> Binding<String> {
        Binding(
            get: {
                overlay.shiftAppearances[shiftTypeID]?.label ?? ""
            },
            set: { newValue in
                var appearance = overlay.shiftAppearances[shiftTypeID]
                    ?? OverlayShiftAppearance(colorHex: ShiftTypeColorOption.peach.rawValue, label: "")
                appearance.label = newValue
                overlay.shiftAppearances[shiftTypeID] = appearance
            }
        )
    }

    private func overlayColorSwatch(_ option: ShiftTypeColorOption, shiftTypeID: UUID) -> some View {
        let selectedHex = overlay.shiftAppearances[shiftTypeID]?.colorHex ?? ""
        let isSelected = selectedHex == option.rawValue
        return Button {
            var appearance = overlay.shiftAppearances[shiftTypeID]
                ?? OverlayShiftAppearance(colorHex: option.rawValue, label: "")
            appearance.colorHex = option.rawValue
            overlay.shiftAppearances[shiftTypeID] = appearance
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 26, height: 26)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.primary, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}