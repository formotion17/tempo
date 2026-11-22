//
//  CalendarsManagementView.swift
//  Tempo
//

import SwiftUI
import UniformTypeIdentifiers

private struct CalendarEditorRequest: Identifiable {
    let id = UUID()
    let calendar: WorkCalendar?
}

struct CalendarsManagementView: View {
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftStore.self) private var shiftStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore

    let onBack: () -> Void

    @State private var editorRequest: CalendarEditorRequest?
    @State private var calendarPendingDeletion: WorkCalendar?
    @State private var showsDeleteConfirmation = false
    @State private var showsAddMenu = false
    @State private var showsFileImporter = false
    @State private var importReview: TempoCalendarExportFile?
    @State private var importErrorMessage: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(calendarStore.calendars) { calendar in
                            calendarCard(calendar)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            if showsAddMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy) {
                            showsAddMenu = false
                        }
                    }

                CalendarAddOptionsMenu(
                    onNewCalendar: {
                        withAnimation(.snappy) {
                            showsAddMenu = false
                        }
                        editorRequest = CalendarEditorRequest(calendar: nil)
                    },
                    onImportCalendar: {
                        withAnimation(.snappy) {
                            showsAddMenu = false
                        }
                        showsFileImporter = true
                    }
                )
                .padding(.top, 52)
                .padding(.trailing, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.snappy(duration: 0.25), value: showsAddMenu)
        .sheet(item: $editorRequest) { request in
            CalendarEditorSheet(calendar: request.calendar) { item in
                if request.calendar != nil {
                    calendarStore.updateCalendar(item)
                } else {
                    calendarStore.addCalendar(item)
                }
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportFile(result)
        }
        .sheet(item: $importReview) { export in
            CalendarImportReviewView(export: export, onImported: {})
        }
        .alert("No se pudo importar", isPresented: importErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Error desconocido")
        }
        .alert("¿Borrar calendario?", isPresented: $showsDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {
                calendarPendingDeletion = nil
            }
            Button("Borrar", role: .destructive) {
                if let calendar = calendarPendingDeletion {
                    deleteCalendar(calendar)
                }
            }
        } message: {
            if let calendar = calendarPendingDeletion {
                Text(deleteConfirmationMessage(for: calendar))
            }
        }
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    private func handleImportFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            importErrorMessage = "No se pudo abrir el archivo."
        case .success(let urls):
            guard let url = urls.first else {
                importErrorMessage = "No se seleccionó ningún archivo."
                return
            }
            do {
                let export = try CalendarImportService.decode(from: url)
                importReview = export
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Calendario")
                        .font(.body.weight(.medium))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Calendarios")
                .font(.headline.weight(.semibold))

            Spacer()

            Button {
                withAnimation(.snappy) {
                    showsAddMenu.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir calendario")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func deleteConfirmationMessage(for calendar: WorkCalendar) -> String {
        let name = calendar.listDisplayName
        if calendar.isImported {
            return "Se borrará «\(name)» con sus turnos reservados y las asignaciones de los días."
        }
        return "Se borrará «\(name)» y las asignaciones de turnos de este calendario."
    }

    private func deleteCalendar(_ calendar: WorkCalendar) {
        calendarStore.removeOverlaysReferencing(sourceCalendarID: calendar.id)
        shiftStore.removeAssignments(forCalendar: calendar.id)
        if calendar.isImported {
            for shiftID in calendar.bundledShiftTypeIDs {
                shiftStore.removeAllShifts(shiftTypeID: shiftID)
                shiftTypeStore.deleteShiftType(id: shiftID)
            }
        }
        calendarStore.deleteCalendar(id: calendar.id)
        calendarPendingDeletion = nil
    }

    private func calendarCard(_ calendar: WorkCalendar) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(calendar.color)
                .frame(width: 44, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.listDisplayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                if calendar.isImported {
                    Text("Solo lectura en días")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !calendar.overlays.isEmpty {
                    Text("\(calendar.overlays.count) calendario(s) superpuesto(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if calendar.id == calendarStore.selectedCalendarID {
                    Text("Activo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    editorRequest = CalendarEditorRequest(calendar: calendar)
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    calendarPendingDeletion = calendar
                    showsDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(calendarStore.calendars.count <= 1)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

extension TempoCalendarExportFile: Identifiable {
    var id: String { calendar.id.uuidString + exportedAt.ISO8601Format() }
}

#Preview {
    CalendarsManagementView(onBack: {})
        .environment(WorkCalendarStore())
        .environment(ShiftTypeStore())
        .environment(ShiftStore())
}