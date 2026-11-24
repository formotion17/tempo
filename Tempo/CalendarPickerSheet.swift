//
//  CalendarPickerSheet.swift
//  Tempo
//

import SwiftUI

struct CalendarPickerSheet: View {
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(calendarStore.calendars) { calendar in
                Button {
                    calendarStore.selectCalendar(calendar)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(calendar.color)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
                            }

                        Text(calendar.listDisplayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        if calendar.id == calendarStore.selectedCalendarID {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Elegir calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TempoSheetToolbar.dismissButton { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    CalendarPickerSheet()
        .environment(WorkCalendarStore())
}