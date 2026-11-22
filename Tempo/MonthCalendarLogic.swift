//
//  MonthCalendarLogic.swift
//  Tempo
//

import Foundation

struct MonthGridDay: Identifiable, Hashable {
    let date: Date
    let isInDisplayedMonth: Bool

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return "\(date.timeIntervalSince1970)"
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

enum MonthCalendarLogic {
    static let fixedWeekRowCount = 6
    static let cellsPerGrid = fixedWeekRowCount * 7

    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date? {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)
    }

    static func isDate(_ date: Date, inSameMonthAs month: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    static func monthGridDays(for month: Date, calendar: Calendar = .current) -> [MonthGridDay] {
        guard let monthStart = monthStart(for: month, calendar: calendar),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leadingCount = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [MonthGridDay] = []

        if leadingCount > 0 {
            for offset in stride(from: -leadingCount, to: 0, by: 1) {
                if let date = calendar.date(byAdding: .day, value: offset, to: monthStart) {
                    cells.append(MonthGridDay(date: date, isInDisplayedMonth: false))
                }
            }
        }

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(MonthGridDay(date: date, isInDisplayedMonth: true))
            }
        }

        guard var cursor = cells.last?.date else { return cells }

        while cells.count % 7 != 0 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            cells.append(
                MonthGridDay(
                    date: next,
                    isInDisplayedMonth: isDate(next, inSameMonthAs: month, calendar: calendar)
                )
            )
        }

        while cells.count < cellsPerGrid {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            cells.append(
                MonthGridDay(
                    date: next,
                    isInDisplayedMonth: isDate(next, inSameMonthAs: month, calendar: calendar)
                )
            )
        }

        return Array(cells.prefix(cellsPerGrid))
    }

    static func shiftedMonth(from date: Date, by offset: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: offset, to: date) ?? date
    }

    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    /// Días del mes alineados en semanas (celdas vacías al inicio).
    static func monthDaySlots(for month: Date, calendar: Calendar = .current) -> [[Date?]] {
        guard let monthStart = monthStart(for: month, calendar: calendar),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        var days: [Date?] = []
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leadingCount = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: leadingCount))

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return stride(from: 0, to: days.count, by: 7).map { index in
            Array(days[index..<min(index + 7, days.count)])
        }
    }

    static func months(inYear year: Int, calendar: Calendar = .current) -> [Date] {
        (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    static func currentYear(calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: Date())
    }

    /// Siempre seis filas para que todos los meses tengan la misma altura en la vista anual.
    static func monthDaySlotsFixedRows(
        for month: Date,
        rows: Int = 6,
        calendar: Calendar = .current
    ) -> [[Date?]] {
        var slots = monthDaySlots(for: month, calendar: calendar)
        while slots.count < rows {
            slots.append(Array(repeating: nil, count: 7))
        }
        return Array(slots.prefix(rows))
    }

    static func spanishWeekdayInitials(calendar: Calendar = .current) -> [String] {
        let mondayFirst = ["L", "M", "X", "J", "V", "S", "D"]
        if calendar.firstWeekday == 1 {
            return ["D", "L", "M", "X", "J", "V", "S"]
        }
        return mondayFirst
    }
}