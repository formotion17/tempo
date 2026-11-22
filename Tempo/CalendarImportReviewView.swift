//
//  CalendarImportReviewView.swift
//  Tempo
//

import SwiftUI

struct CalendarImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(ShiftStore.self) private var shiftStore

    let export: TempoCalendarExportFile
    let onImported: () -> Void

    private var resolvedName: String {
        CalendarImportService.uniqueCalendarName(export.calendar.name, existing: calendarStore.calendars)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Calendario") {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(export.calendar.color)
                            .frame(width: 40, height: 40)
                        Text(resolvedName)
                            .font(.headline.weight(.semibold))
                    }
                }

                Section("Turnos (\(export.shiftTypes.count))") {
                    if export.shiftTypes.isEmpty {
                        Text("Sin tipos de turno en el archivo.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(export.shiftTypes) { shiftType in
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
                }

                Section {
                    Text("Se importarán \(export.assignmentsByDay.count) días con asignaciones. El calendario quedará en solo lectura: podrás cambiar nombre, abreviaturas y qué turnos se ven, pero no los días.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Vista previa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") {
                        applyImport()
                        onImported()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyImport() {
        for shiftType in export.shiftTypes {
            if shiftTypeStore.shiftType(id: shiftType.id) != nil {
                shiftTypeStore.updateShiftType(shiftType)
            } else {
                shiftTypeStore.addShiftType(shiftType)
            }
        }

        let bundledIDs = export.shiftTypes.map(\.id)
        let visibleIDs: [UUID] = {
            if !export.calendar.shiftTypeIDs.isEmpty {
                return export.calendar.shiftTypeIDs.filter { bundledIDs.contains($0) }
            }
            return bundledIDs
        }()

        let calendar = WorkCalendar(
            id: UUID(),
            name: resolvedName,
            colorHex: export.calendar.colorHex,
            shiftTypeIDs: visibleIDs,
            bundledShiftTypeIDs: bundledIDs,
            isImported: true
        )
        calendarStore.addCalendar(calendar)
        calendarStore.selectCalendar(calendar)
        shiftStore.setAssignments(export.assignmentsByDay, calendarID: calendar.id)
    }
}

#Preview {
    CalendarImportReviewView(
        export: TempoCalendarExportFile(
            calendar: WorkCalendar(name: "Equipo", colorHex: ShiftTypeColorOption.sky.rawValue),
            shiftTypes: [
                ShiftTypeDefinition(name: "Mañana", initials: "Mañ", colorHex: ShiftTypeColorOption.morningYellow.rawValue, schedule: "08:00 – 15:00"),
            ],
            assignmentsByDay: ["2026-11-16": [ShiftEntry(shiftTypeID: UUID())]]
        ),
        onImported: {}
    )
    .environment(WorkCalendarStore())
    .environment(ShiftTypeStore())
    .environment(ShiftStore())
}