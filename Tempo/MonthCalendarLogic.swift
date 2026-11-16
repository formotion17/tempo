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
}