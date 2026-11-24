//
//  CalendarYearDayZoomSheet.swift
//  Tempo
//

import SwiftUI

struct ZoomedDayPresentation: Identifiable {
    let date: Date
    var id: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

struct CalendarYearDayZoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(ShiftStore.self) private var shiftStore

    let date: Date

    private var calendar: Calendar { Calendar.current }

    private var host: WorkCalendar {
        calendarStore.selectedCalendar
    }

    private var titleText: String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "es_ES")))
            .capitalized
    }

    private var mainShiftTypes: [ShiftTypeDefinition] {
        let entries = shiftStore.shifts(for: date, calendarID: host.id, calendar: calendar)
        return entries.compactMap { shiftTypeStore.shiftType(id: $0.shiftTypeID) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CalendarCompactDayCell(
                        date: date,
                        workCalendarID: host.id,
                        hostCalendar: host,
                        cellSize: 176,
                        overlayDotDiameter: 14
                    )
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(white: 0.93))
                    }

                    dayLegend
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.white)
            .scrollContentBackground(.hidden)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TempoSheetToolbar.dismissButton { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.94)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var dayLegend: some View {
        VStack(alignment: .leading, spacing: 16) {
            legendSection(title: host.name) {
                if mainShiftTypes.isEmpty {
                    Text("Sin turnos este día")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mainShiftTypes) { shift in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(shift.color)
                                .frame(width: 28, height: 22)
                            Text(shift.name)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }

            ForEach(host.overlays) { overlay in
                if let source = calendarStore.calendar(id: overlay.sourceCalendarID) {
                    let overlayShifts = overlayShiftTypes(overlay: overlay)
                    if !overlayShifts.isEmpty {
                        legendSection(title: source.listDisplayName) {
                            ForEach(overlayShifts, id: \.shift.id) { item in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(item.dotColor)
                                        .frame(width: 16, height: 16)
                                        .overlay {
                                            Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
                                        }
                                    Text(item.shift.name)
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overlayShiftTypes(overlay: CalendarOverlay) -> [(shift: ShiftTypeDefinition, dotColor: Color)] {
        let entries = shiftStore.shifts(for: date, calendarID: overlay.sourceCalendarID, calendar: calendar)
        return entries.compactMap { entry -> (ShiftTypeDefinition, Color)? in
            guard overlay.includes(shiftTypeID: entry.shiftTypeID),
                  let shift = shiftTypeStore.shiftType(id: entry.shiftTypeID) else { return nil }
            let appearance = overlay.bubbleAppearance(for: entry.shiftTypeID, shiftTypeStore: shiftTypeStore)
            return (shift, appearance.color)
        }
    }

    private func legendSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
    }
}