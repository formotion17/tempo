//
//  CalendarDayIndicators.swift
//  Tempo
//

import Foundation
import SwiftUI

enum CalendarDayIndicators {
    static func hasMainAssignment(
        date: Date,
        calendarID: UUID,
        shiftStore: ShiftStore,
        calendar: Calendar = .current
    ) -> Bool {
        !shiftStore.shifts(for: date, calendarID: calendarID, calendar: calendar).isEmpty
    }

    static func overlayDotColors(
        date: Date,
        hostCalendar: WorkCalendar,
        shiftStore: ShiftStore,
        shiftTypeStore: ShiftTypeStore,
        calendar: Calendar = .current
    ) -> [Color] {
        guard !hostCalendar.isImported else { return [] }
        var colors: [Color] = []
        for overlay in hostCalendar.overlays {
            let entries = shiftStore.shifts(for: date, calendarID: overlay.sourceCalendarID, calendar: calendar)
            for entry in entries where overlay.includes(shiftTypeID: entry.shiftTypeID) {
                let appearance = overlay.bubbleAppearance(for: entry.shiftTypeID, shiftTypeStore: shiftTypeStore)
                colors.append(appearance.color)
            }
        }
        return colors
    }
}