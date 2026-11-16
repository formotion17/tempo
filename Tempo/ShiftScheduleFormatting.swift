//
//  ShiftScheduleFormatting.swift
//  Tempo
//

import Foundation

enum ShiftScheduleFormatting {
    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    static func string(from start: Date, to end: Date) -> String {
        "\(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
    }

    static func parsedTimes(from schedule: String, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let trimmed = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed
            .replacingOccurrences(of: "–", with: "-")
            .split(separator: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2 else { return nil }

        let today = calendar.startOfDay(for: .now)
        guard
            let start = timeFormatter.date(from: String(parts[0])),
            let end = timeFormatter.date(from: String(parts[1]))
        else { return nil }

        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)

        guard
            let startDate = calendar.date(bySettingHour: startComponents.hour ?? 0, minute: startComponents.minute ?? 0, second: 0, of: today),
            let endDate = calendar.date(bySettingHour: endComponents.hour ?? 0, minute: endComponents.minute ?? 0, second: 0, of: today)
        else { return nil }

        return (startDate, endDate)
    }

    static func defaultStart(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 8, minute: 0, second: 0, of: calendar.startOfDay(for: .now)) ?? .now
    }

    static func defaultEnd(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 16, minute: 0, second: 0, of: calendar.startOfDay(for: .now)) ?? .now
    }
}