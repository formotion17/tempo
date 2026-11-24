//
//  TempoCalendarExportReviewView.swift
//  Tempo
//

import SwiftUI

struct TempoCalendarExportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(ShiftStore.self) private var shiftStore

    let calendarID: UUID
    let onConfirm: (TempoCalendarExportFile) -> Void

    @State private var includedShiftTypeIDs: Set<UUID> = []
    @State private var includedOverlaySourceIDs: Set<UUID> = []

    private var host: WorkCalendar? {
        calendarStore.calendar(id: calendarID)
    }

    private var hostAssignments: DayAssignments {
        shiftStore.assignments(for: calendarID)
    }

    private var candidateShiftTypes: [ShiftTypeDefinition] {
        guard let host else { return [] }
        let ids = CalendarExportService.exportableShiftTypeIDs(for: host, assignments: hostAssignments)
        return ids.compactMap { shiftTypeStore.shiftType(id: $0) }
    }

    private var overlayBlocks: [(overlay: CalendarOverlay, source: WorkCalendar)] {
        guard let host else { return [] }
        return host.overlays.compactMap { overlay in
            guard let source = calendarStore.calendar(id: overlay.sourceCalendarID) else { return nil }
            return (overlay, source)
        }
    }

    private var builtExport: TempoCalendarExportFile? {
        guard let host else { return nil }
        return CalendarExportService.buildExport(
            calendar: host,
            shiftTypes: shiftTypeStore.shiftTypes,
            assignments: hostAssignments,
            includedShiftTypeIDs: includedShiftTypeIDs,
            includedOverlaySourceIDs: includedOverlaySourceIDs,
            calendarStore: calendarStore,
            shiftStore: shiftStore
        )
    }

    private var canConfirm: Bool {
        !includedShiftTypeIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if let host {
                    Section("Calendario") {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(host.color)
                                .frame(width: 40, height: 40)
                            Text(host.name)
                                .font(.headline.weight(.semibold))
                        }
                    }

                    Section {
                        if candidateShiftTypes.isEmpty {
                            Text("No hay turnos que exportar en este calendario.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(candidateShiftTypes) { shift in
                                Toggle(isOn: shiftBinding(shift.id)) {
                                    HStack(spacing: 10) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(shift.color)
                                            .frame(width: 28, height: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(shift.name)
                                                .font(.subheadline.weight(.medium))
                                            Text(shift.displayInitials)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Turnos a exportar")
                    } footer: {
                        Text("Solo se exportan las asignaciones de los turnos marcados.")
                    }

                    if !overlayBlocks.isEmpty {
                        Section {
                            ForEach(overlayBlocks, id: \.overlay.id) { block in
                                Toggle(isOn: overlayBinding(block.source.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(block.source.listDisplayName)
                                            .font(.subheadline.weight(.medium))
                                        Text("\(block.overlay.includedShiftTypeIDs.count) turno(s) en la superposición")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Calendarios superpuestos")
                        } footer: {
                            Text("Si lo incluyes, se exporta el calendario de origen con las asignaciones visibles en la superposición.")
                        }
                    }
                }

                if let export = builtExport {
                    Section("Resumen del archivo") {
                        summaryRow("Turnos en el paquete", value: "\(export.shiftTypes.count)")
                        summaryRow(
                            "Días con turnos (principal)",
                            value: "\(TempoTransferStats.daysWithAssignments(export.assignmentsByDay))"
                        )
                        summaryRow("Superposiciones", value: "\(export.calendar.overlays.count)")
                        summaryRow("Calendarios añadidos", value: "\(export.companionCalendars.count)")
                    }
                }
            }
            .navigationTitle("Resumen de exportación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TempoSheetToolbar.dismissButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    TempoSheetToolbar.saveButton(disabled: !canConfirm) {
                        guard let export = builtExport else { return }
                        onConfirm(export)
                        dismiss()
                    }
                }
            }
            .onAppear {
                seedDefaults()
            }
        }
    }

    private func seedDefaults() {
        guard let host else { return }
        let shifts = Set(CalendarExportService.exportableShiftTypeIDs(for: host, assignments: hostAssignments))
        includedShiftTypeIDs = shifts
        includedOverlaySourceIDs = Set(host.overlays.map(\.sourceCalendarID))
    }

    private func shiftBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { includedShiftTypeIDs.contains(id) },
            set: { enabled in
                if enabled {
                    includedShiftTypeIDs.insert(id)
                } else {
                    includedShiftTypeIDs.remove(id)
                }
            }
        )
    }

    private func overlayBinding(_ sourceID: UUID) -> Binding<Bool> {
        Binding(
            get: { includedOverlaySourceIDs.contains(sourceID) },
            set: { enabled in
                if enabled {
                    includedOverlaySourceIDs.insert(sourceID)
                } else {
                    includedOverlaySourceIDs.remove(sourceID)
                }
            }
        )
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}