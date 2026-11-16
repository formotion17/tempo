//
//  CalendarsManagementView.swift
//  Tempo
//

import SwiftUI

struct CalendarsManagementView: View {
    @Environment(WorkCalendarStore.self) private var calendarStore

    let onBack: () -> Void

    @State private var showsEditor = false
    @State private var editingCalendar: WorkCalendar?

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showsEditor) {
            CalendarEditorSheet(calendar: editingCalendar) { item in
                if editingCalendar != nil {
                    calendarStore.updateCalendar(item)
                } else {
                    calendarStore.addCalendar(name: item.name, colorHex: item.colorHex)
                }
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
                editingCalendar = nil
                showsEditor = true
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
                Text(calendar.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                if calendar.id == calendarStore.selectedCalendarID {
                    Text("Activo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    editingCalendar = calendar
                    showsEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    calendarStore.deleteCalendar(id: calendar.id)
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

#Preview {
    CalendarsManagementView(onBack: {})
        .environment(WorkCalendarStore())
}