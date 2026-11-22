//
//  ShiftModels.swift
//  Tempo
//

import Foundation

struct ShiftEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var shiftTypeID: UUID

    init(id: UUID = UUID(), shiftTypeID: UUID) {
        self.id = id
        self.shiftTypeID = shiftTypeID
    }
}

typealias DayAssignments = [String: [ShiftEntry]]

@Observable
final class ShiftStore {
    private var storage: [UUID: DayAssignments] = [:]

    init() {
        if let scoped = AppPersistence.loadShiftAssignmentsByCalendar() {
            storage = scoped.reduce(into: [UUID: DayAssignments]()) { result, pair in
                if let id = UUID(uuidString: pair.key) {
                    result[id] = pair.value
                }
            }
        } else if let legacy = AppPersistence.loadShiftAssignments(),
                  let selected = AppPersistence.loadWorkCalendarState()?.selectedCalendarID {
            storage[selected] = legacy
            persist()
        }
    }

    private func bucket(for calendarID: UUID) -> DayAssignments {
        storage[calendarID] ?? [:]
    }

    func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return "\(date.timeIntervalSince1970)"
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func shifts(for date: Date, calendarID: UUID, calendar: Calendar = .current) -> [ShiftEntry] {
        let key = dayKey(for: date, calendar: calendar)
        return bucket(for: calendarID)[key] ?? []
    }

    static let maxShiftsPerDay = 4

    func addShift(shiftTypeID: UUID, on date: Date, calendarID: UUID, calendar: Calendar = .current) {
        let day = dayKey(for: date, calendar: calendar)
        var days = bucket(for: calendarID)
        var entries = days[day] ?? []
        guard !entries.contains(where: { $0.shiftTypeID == shiftTypeID }) else { return }
        guard entries.count < Self.maxShiftsPerDay else { return }
        entries.append(ShiftEntry(shiftTypeID: shiftTypeID))
        days[day] = entries
        storage[calendarID] = days
        persist()
    }

    func clearDay(on date: Date, calendarID: UUID, calendar: Calendar = .current) {
        let day = dayKey(for: date, calendar: calendar)
        var days = bucket(for: calendarID)
        days[day] = []
        storage[calendarID] = days
        persist()
    }

    func removeShift(shiftTypeID: UUID, on date: Date, calendarID: UUID, calendar: Calendar = .current) {
        let day = dayKey(for: date, calendar: calendar)
        var days = bucket(for: calendarID)
        days[day] = days[day]?.filter { $0.shiftTypeID != shiftTypeID }
        storage[calendarID] = days
        persist()
    }

    func removeAllShifts(shiftTypeID: UUID) {
        for calendarID in storage.keys {
            var days = storage[calendarID] ?? [:]
            for day in days.keys {
                days[day] = days[day]?.filter { $0.shiftTypeID != shiftTypeID }
            }
            storage[calendarID] = days
        }
        persist()
    }

    func assignments(for calendarID: UUID) -> DayAssignments {
        bucket(for: calendarID)
    }

    func setAssignments(_ assignments: DayAssignments, calendarID: UUID) {
        storage[calendarID] = assignments
        persist()
    }

    func mergeAssignments(_ imported: DayAssignments, calendarID: UUID) {
        var days = bucket(for: calendarID)
        for (dayKey, entries) in imported {
            var merged = days[dayKey] ?? []
            for entry in entries {
                guard !merged.contains(where: { $0.shiftTypeID == entry.shiftTypeID }) else { continue }
                guard merged.count < Self.maxShiftsPerDay else { continue }
                merged.append(ShiftEntry(shiftTypeID: entry.shiftTypeID))
            }
            days[dayKey] = merged
        }
        storage[calendarID] = days
        persist()
    }

    func removeAssignments(forCalendar calendarID: UUID) {
        storage.removeValue(forKey: calendarID)
        persist()
    }

    func persistAssignments() {
        persist()
    }

    private func persist() {
        let encoded = storage.reduce(into: [String: DayAssignments]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        AppPersistence.saveShiftAssignmentsByCalendar(encoded)
    }
}