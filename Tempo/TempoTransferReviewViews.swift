//
//  TempoTransferReviewViews.swift
//  Tempo
//

import SwiftUI

enum TempoTransferStats {
    static func daysWithAssignments(_ assignments: DayAssignments) -> Int {
        assignments.filter { !$0.value.isEmpty }.count
    }

    static func shiftAssignmentCount(_ assignments: DayAssignments) -> Int {
        assignments.values.reduce(0) { $0 + $1.count }
    }
}

// MARK: - Exportar

struct TempoExportReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let export: TempoDatabaseExportFile
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            TempoTransferSummaryList(payload: .database(export), isExport: true)
            .navigationTitle("Exportar base de datos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TempoSheetToolbar.dismissButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    TempoSheetToolbar.saveButton {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Importar

struct TempoImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(ShiftStore.self) private var shiftStore

    let payload: TempoImportPayload
    let onImported: () -> Void

    var body: some View {
        NavigationStack {
            TempoTransferSummaryList(
                payload: payload,
                isExport: false,
                resolvedCalendarName: resolvedCalendarName
            )
            .navigationTitle("Resumen de importación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TempoSheetToolbar.dismissButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") {
                        applyImport()
                        onImported()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    private var resolvedCalendarName: String? {
        guard case .calendar(let export) = payload else { return nil }
        return CalendarImportService.uniqueCalendarName(export.calendar.name, existing: calendarStore.calendars)
    }

    private func applyImport() {
        switch payload {
        case .calendar(let export):
            applyCalendarImport(export)
        case .database(let export):
            applyDatabaseImport(export)
        }
    }

    private func applyCalendarImport(_ export: TempoCalendarExportFile) {
        mergeShiftTypes(from: export.shiftTypes)

        for companion in export.companionCalendars {
            importCompanionCalendar(companion, export: export)
        }

        let bundledIDs = export.shiftTypes.map(\.id)
        let visibleIDs: [UUID] = {
            if !export.calendar.shiftTypeIDs.isEmpty {
                return export.calendar.shiftTypeIDs.filter { bundledIDs.contains($0) }
            }
            return bundledIDs
        }()

        let name = resolvedCalendarName ?? export.calendar.name
        let calendar = WorkCalendar(
            id: UUID(),
            name: name,
            colorHex: export.calendar.colorHex,
            shiftTypeIDs: visibleIDs,
            bundledShiftTypeIDs: export.calendar.bundledShiftTypeIDs.isEmpty
                ? bundledIDs
                : export.calendar.bundledShiftTypeIDs,
            isImported: true,
            overlays: export.calendar.overlays
        )
        calendarStore.addCalendar(calendar)
        calendarStore.selectCalendar(calendar)
        shiftStore.setAssignments(export.assignmentsByDay, calendarID: calendar.id)
    }

    private func mergeShiftTypes(from types: [ShiftTypeDefinition]) {
        for shiftType in types {
            if shiftTypeStore.shiftType(id: shiftType.id) != nil {
                shiftTypeStore.updateShiftType(shiftType)
            } else {
                shiftTypeStore.addShiftType(shiftType)
            }
        }
    }

    private func importCompanionCalendar(_ companion: WorkCalendar, export: TempoCalendarExportFile) {
        let assignments = export.companionAssignmentsByCalendarID[companion.id.uuidString] ?? [:]
        let companionTypes = export.shiftTypes.filter { type in
            companion.bundledShiftTypeIDs.contains(type.id) || companion.shiftTypeIDs.contains(type.id)
        }
        mergeShiftTypes(from: companionTypes)

        let importedCompanion: WorkCalendar
        if let existingIndex = calendarStore.calendars.firstIndex(where: { $0.id == companion.id }) {
            var existing = calendarStore.calendars[existingIndex]
            existing.name = companion.name
            existing.colorHex = companion.colorHex
            existing.shiftTypeIDs = companion.shiftTypeIDs
            existing.bundledShiftTypeIDs = companion.bundledShiftTypeIDs
            existing.isImported = companion.isImported
            existing.overlays = []
            calendarStore.updateCalendar(existing)
            importedCompanion = existing
        } else {
            var newCompanion = companion
            newCompanion.overlays = []
            calendarStore.addCalendar(newCompanion)
            importedCompanion = newCompanion
        }

        shiftStore.setAssignments(assignments, calendarID: importedCompanion.id)
    }

    private func applyDatabaseImport(_ export: TempoDatabaseExportFile) {
        shiftTypeStore.replaceAll(with: export.shiftTypes)
        calendarStore.replaceAll(calendars: export.calendars, selectedCalendarID: export.selectedCalendarID)

        let assignments = export.assignmentsByCalendarID.reduce(into: [UUID: DayAssignments]()) { result, pair in
            guard let id = UUID(uuidString: pair.key) else { return }
            result[id] = pair.value
        }
        shiftStore.replaceAll(assignments)
    }
}

// MARK: - Contenido compartido

private struct TempoTransferSummaryList: View {
    let payload: TempoImportPayload
    var isExport: Bool = false
    var resolvedCalendarName: String?

    var body: some View {
        List {
            switch payload {
            case .calendar(let export):
                singleCalendarSections(export)
            case .database(let export):
                databaseSections(export)
            }
        }
    }

    @ViewBuilder
    private func singleCalendarSections(_ export: TempoCalendarExportFile) -> some View {
        Section("Calendario") {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(export.calendar.color)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedCalendarName ?? export.calendar.name)
                        .font(.headline.weight(.semibold))
                    Text(export.calendar.isImported ? "Solo lectura en días" : "Editable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            summaryRow("Superposiciones", value: "\(export.calendar.overlays.count)")
            summaryRow("Calendarios superpuestos incluidos", value: "\(export.companionCalendars.count)")
            summaryRow("Turnos en paleta", value: "\(export.calendar.shiftTypeIDs.count)")
        }

        Section("Turnos incluidos (\(export.shiftTypes.count))") {
            if export.shiftTypes.isEmpty {
                Text("Sin tipos de turno en el archivo.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(export.shiftTypes) { shiftType in
                    shiftRow(shiftType)
                }
            }
        }

        Section("Asignaciones") {
            let days = TempoTransferStats.daysWithAssignments(export.assignmentsByDay)
            let slots = TempoTransferStats.shiftAssignmentCount(export.assignmentsByDay)
            summaryRow("Días con turnos", value: "\(days)")
            summaryRow("Asignaciones totales", value: "\(slots)")
        }

        Section {
            Group {
                if isExport {
                    Text(
                        "Al exportar se incluyen metadatos del calendario, turnos empaquetados y todas las asignaciones por día."
                    )
                } else {
                    Text(
                        "Se añadirá como calendario importado (solo lectura en días). Podrás cambiar nombre, abreviaturas y qué turnos se muestran."
                    )
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func databaseSections(_ export: TempoDatabaseExportFile) -> some View {
        Section("Contenido del archivo") {
            summaryRow("Calendarios", value: "\(export.calendars.count)")
            let imported = export.calendars.filter(\.isImported).count
            let editable = export.calendars.count - imported
            summaryRow("Editables / importados", value: "\(editable) / \(imported)")
            summaryRow("Turnos en biblioteca", value: "\(export.shiftTypes.count)")
            let allAssignments = export.assignmentsByCalendarID.values.reduce(into: DayAssignments()) { result, days in
                for (key, entries) in days where !entries.isEmpty {
                    result[key] = entries
                }
            }
            summaryRow("Días con turnos (global)", value: "\(TempoTransferStats.daysWithAssignments(allAssignments))")
            summaryRow("Asignaciones totales", value: "\(TempoTransferStats.shiftAssignmentCount(allAssignments))")
            if let selected = export.calendars.first(where: { $0.id == export.selectedCalendarID }) {
                summaryRow("Calendario activo al exportar", value: selected.listDisplayName)
            }
        }

        Section("Calendarios") {
            ForEach(export.calendars) { calendar in
                let assignments = export.assignmentsByCalendarID[calendar.id.uuidString] ?? [:]
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(calendar.color)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendar.name)
                                .font(.subheadline.weight(.semibold))
                            Text(calendar.isImported ? "Solo lectura en días" : "Editable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(
                        "\(TempoTransferStats.daysWithAssignments(assignments)) días con turnos · \(calendar.overlays.count) superposición(es) · \(calendar.shiftTypeIDs.count) turno(s) en paleta"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }

        Section("Turnos (\(export.shiftTypes.count))") {
            if export.shiftTypes.isEmpty {
                Text("Sin turnos en la biblioteca.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(export.shiftTypes) { shiftType in
                    shiftRow(shiftType)
                }
            }
        }

        Section {
            Text(
                isExport
                    ? "Incluye todos los calendarios con su modo editable o importado, superposiciones, biblioteca de turnos y asignaciones por calendario."
                    : "La importación sustituirá todos los calendarios, turnos y asignaciones actuales por los del archivo. El estado quedará como al exportar."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func shiftRow(_ shiftType: ShiftTypeDefinition) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(shiftType.color)
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(shiftType.name)
                    .font(.body.weight(.semibold))
                Text("Abreviatura: \(shiftType.displayInitials)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}