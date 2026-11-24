//
//  CalendarYearSummarySheet.swift
//  Tempo
//

import SwiftUI

struct CalendarYearSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(ShiftStore.self) private var shiftStore

    let year: Int

    private var host: WorkCalendar {
        calendarStore.selectedCalendar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    calendarSection(
                        title: host.name,
                        shiftTypes: shiftTypeStore.shiftTypes(linkedTo: host.shiftTypeIDs),
                        counts: shiftStore.shiftTypeCounts(inYear: year, calendarID: host.id)
                    )

                    ForEach(host.overlays) { overlay in
                        if let source = calendarStore.calendar(id: overlay.sourceCalendarID) {
                            let filter = Set(overlay.includedShiftTypeIDs)
                            let types = overlay.includedShiftTypeIDs.compactMap {
                                shiftTypeStore.shiftType(id: $0)
                            }
                            if !types.isEmpty {
                                calendarSection(
                                    title: source.listDisplayName,
                                    shiftTypes: types,
                                    counts: shiftStore.shiftTypeCounts(
                                        inYear: year,
                                        calendarID: source.id,
                                        onlyShiftTypeIDs: filter
                                    )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resumen \(String(year))")
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

    private func calendarSection(
        title: String,
        shiftTypes: [ShiftTypeDefinition],
        counts: [UUID: Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(shiftTypes) { shift in
                    let count = counts[shift.id, default: 0]
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(shift.color)
                            .frame(width: 24, height: 18)
                        Text(shift.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(count == 0 ? .tertiary : .primary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if shift.id != shiftTypes.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}