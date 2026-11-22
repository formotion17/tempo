//
//  CalendarEditorSheet.swift
//  Tempo
//

import SwiftUI

struct CalendarEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(WorkCalendarStore.self) private var calendarStore

    let title: String
    let onSave: (WorkCalendar) -> Void

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var selectedShiftTypeIDs: Set<UUID>
    @State private var shiftInitials: [UUID: String]
    @State private var overlays: [CalendarOverlay]
    @State private var showsOverlaySourcePicker = false

    private let editingCalendar: WorkCalendar?

    init(calendar: WorkCalendar? = nil, onSave: @escaping (WorkCalendar) -> Void) {
        self.editingCalendar = calendar
        self.title = calendar == nil ? "Nuevo calendario" : (calendar?.isImported == true ? "Calendario importado" : "Editar calendario")
        self.onSave = onSave
        _name = State(initialValue: calendar?.name ?? "")
        _selectedColorHex = State(initialValue: calendar?.colorHex ?? ShiftTypeColorOption.sky.rawValue)
        let initialIDs = calendar?.shiftTypeIDs ?? []
        _selectedShiftTypeIDs = State(initialValue: Set(initialIDs))
        _shiftInitials = State(initialValue: [:])
        _overlays = State(initialValue: calendar?.overlays ?? [])
    }

    private var availableOverlaySources: [WorkCalendar] {
        let used = Set(overlays.map(\.sourceCalendarID))
        return calendarStore.overlaySourceCandidates(
            excluding: editingCalendar?.id,
            alreadyUsed: used
        )
    }

    private var isImportedMode: Bool {
        editingCalendar?.isImported == true
    }

    private var bundledShiftTypes: [ShiftTypeDefinition] {
        guard let calendar = editingCalendar else { return [] }
        let order = calendar.bundledShiftTypeIDs
        return order.compactMap { id in shiftTypeStore.shiftType(id: id) }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Equipo A", text: $name)
                }

                if !isImportedMode {
                    Section("Color de cabecera") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(ShiftTypeColorOption.allCases) { option in
                                colorSwatch(option)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    overlaysSection
                }

                if isImportedMode {
                    Section {
                        ForEach(bundledShiftTypes) { shiftType in
                            importedShiftRow(shiftType)
                        }
                    } header: {
                        Text("Turnos del calendario")
                    } footer: {
                        Text("Puedes cambiar la abreviatura y qué turnos se muestran. El contenido de los días no se puede modificar.")
                    }
                } else {
                    Section {
                        if shiftTypeStore.shiftTypes.isEmpty {
                            Text("Crea turnos en la pestaña Turnos para poder añadirlos aquí.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(shiftTypeStore.shiftTypes) { shiftType in
                                shiftTypeToggleRow(shiftType)
                            }
                        }
                    } header: {
                        Text("Turnos en este calendario")
                    } footer: {
                        Text("Solo los turnos marcados aparecerán en la paleta de este calendario.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                seedImportedInitialsIfNeeded()
            }
            .sheet(isPresented: $showsOverlaySourcePicker) {
                overlaySourcePickerSheet
            }
        }
        .presentationDetents([.large])
    }

    private var overlaySourcePickerSheet: some View {
        NavigationStack {
            List(availableOverlaySources) { source in
                Button {
                    overlays.append(CalendarOverlay.makeDefault(source: source, shiftTypeStore: shiftTypeStore))
                    showsOverlaySourcePicker = false
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(source.color)
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.listDisplayName)
                                .foregroundStyle(.primary)
                            if source.isImported {
                                Text("Importado")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendario a superponer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showsOverlaySourcePicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func seedImportedInitialsIfNeeded() {
        guard isImportedMode else { return }
        for shift in bundledShiftTypes {
            if shiftInitials[shift.id] == nil {
                shiftInitials[shift.id] = shift.initials
            }
        }
    }

    private func save() {
        if isImportedMode, let existing = editingCalendar {
            for shift in bundledShiftTypes {
                guard var updated = shiftTypeStore.shiftType(id: shift.id) else { continue }
                let newInitials = shiftInitials[shift.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? updated.initials
                updated.initials = newInitials
                shiftTypeStore.updateShiftType(updated)
            }

            let visibleIDs = existing.bundledShiftTypeIDs.filter { selectedShiftTypeIDs.contains($0) }
            let calendar = WorkCalendar(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: existing.colorHex,
                shiftTypeIDs: visibleIDs,
                bundledShiftTypeIDs: existing.bundledShiftTypeIDs,
                isImported: true,
                overlays: []
            )
            onSave(calendar)
        } else {
            let orderedIDs = shiftTypeStore.shiftTypes
                .map(\.id)
                .filter { selectedShiftTypeIDs.contains($0) }
            let calendar = WorkCalendar(
                id: editingCalendar?.id ?? UUID(),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: selectedColorHex,
                shiftTypeIDs: orderedIDs,
                bundledShiftTypeIDs: editingCalendar?.bundledShiftTypeIDs ?? [],
                isImported: editingCalendar?.isImported ?? false,
                overlays: overlays
            )
            onSave(calendar)
        }
        dismiss()
    }

    private func importedShiftRow(_ shiftType: ShiftTypeDefinition) -> some View {
        let isVisible = selectedShiftTypeIDs.contains(shiftType.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(shiftType.color)
                    .frame(width: 32, height: 32)

                Text(shiftType.name)
                    .font(.body.weight(.semibold))

                Spacer()

                Button {
                    if isVisible {
                        selectedShiftTypeIDs.remove(shiftType.id)
                    } else {
                        selectedShiftTypeIDs.insert(shiftType.id)
                    }
                } label: {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                        .foregroundStyle(isVisible ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible ? "Visible en paleta" : "Oculto en paleta")
            }

            HStack {
                Text("Abreviatura")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Ej. Mañ", text: initialsBinding(for: shiftType.id))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private func initialsBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { shiftInitials[id] ?? "" },
            set: { shiftInitials[id] = $0 }
        )
    }

    private func shiftTypeToggleRow(_ shiftType: ShiftTypeDefinition) -> some View {
        let isOn = selectedShiftTypeIDs.contains(shiftType.id)
        return Button {
            if isOn {
                selectedShiftTypeIDs.remove(shiftType.id)
            } else {
                selectedShiftTypeIDs.insert(shiftType.id)
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(shiftType.color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(shiftType.name)
                        .foregroundStyle(.primary)
                    Text(shiftType.displayInitials)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.4))
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var overlaysSection: some View {
        Section {
            if overlays.isEmpty {
                Text("Superpón otro calendario (por ejemplo vacaciones importadas) sobre este.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($overlays) { $overlay in
                    if let source = calendarStore.calendar(id: overlay.sourceCalendarID) {
                        NavigationLink {
                            CalendarOverlayEditorView(overlay: $overlay)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.listDisplayName)
                                    .font(.body.weight(.semibold))
                                Text("\(overlay.includedShiftTypeIDs.count) turno(s) en burbuja")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    overlays.remove(atOffsets: offsets)
                }
            }

            if availableOverlaySources.isEmpty {
                Text("Necesitas al menos otro calendario. Importa uno con + → Importar calendario.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    if availableOverlaySources.count == 1, let source = availableOverlaySources.first {
                        overlays.append(CalendarOverlay.makeDefault(source: source, shiftTypeStore: shiftTypeStore))
                    } else {
                        showsOverlaySourcePicker = true
                    }
                } label: {
                    Label("Añadir calendario superpuesto", systemImage: "square.stack.3d.up.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        } header: {
            Text("Calendarios superpuestos")
        } footer: {
            Text("Aparecen burbujas abajo en cada día. Pulsa Guardar al terminar.")
        }
    }

    private func colorSwatch(_ option: ShiftTypeColorOption) -> some View {
        let isSelected = selectedColorHex == option.rawValue
        return Button {
            selectedColorHex = option.rawValue
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 40, height: 40)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 2)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarEditorSheet { _ in }
        .environment(ShiftTypeStore())
        .environment(WorkCalendarStore())
}