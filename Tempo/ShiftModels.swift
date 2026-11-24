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
    static let maxUndoSteps = 10

    private var storage: [UUID: DayAssignments] = [:]
    private var undoStacks: [UUID: [DayAssignments]] = [:]
    private var suppressUndoRecording = false

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

    func canUndo(calendarID: UUID) -> Bool {
        !(undoStacks[calendarID]?.isEmpty ?? true)
    }

    func pendingUndoSteps(calendarID: UUID) -> Int {
        undoStacks[calendarID]?.count ?? 0
    }

    func undo(calendarID: UUID) {
        guard var stack = undoStacks[calendarID], let previous = stack.popLast() else { return }
        if stack.isEmpty {
            undoStacks.removeValue(forKey: calendarID)
        } else {
            undoStacks[calendarID] = stack
        }

        suppressUndoRecording = true
        storage[calendarID] = Self.copyAssignments(previous)
        suppressUndoRecording = false
        persist()
    }

    func addShift(shiftTypeID: UUID, on date: Date, calendarID: UUID, calendar: Calendar = .current) {
        let day = dayKey(for: date, calendar: calendar)
        var days = bucket(for: calendarID)
        var entries = days[day] ?? []
        guard !entries.contains(where: { $0.shiftTypeID == shiftTypeID }) else { return }
        guard entries.count < Self.maxShiftsPerDay else { return }
        recordUndo(calendarID: calendarID)
        entries.append(ShiftEntry(shiftTypeID: shiftTypeID))
        days[day] = entries
        storage[calendarID] = days
        persist()
    }

    func clearDay(on date: Date, calendarID: UUID, calendar: Calendar = .current) {
        let day = dayKey(for: date, calendar: calendar)
        var days = bucket(for: calendarID)
        let entries = days[day] ?? []
        guard !entries.isEmpty else { return }
        recordUndo(calendarID: calendarID)
        days[day] = []
        storage[calendarID] = days
        persist()
    }

    func removeShift(shiftTypeID: UUID, on date: Date, calendarID: UUID, calendar: Calendar = .current) {
        let day = dayKey(for: date, calendar: calendar)
        var days = bucket(for: calendarID)
        guard days[day]?.contains(where: { $0.shiftTypeID == shiftTypeID }) == true else { return }
        recordUndo(calendarID: calendarID)
        days[day] = days[day]?.filter { $0.shiftTypeID != shiftTypeID }
        storage[calendarID] = days
        persist()
    }

    func removeAllShifts(shiftTypeID: UUID) {
        undoStacks.removeAll()
        for calendarID in storage.keys {
            var days = storage[calendarID] ?? [:]
            for day in days.keys {
                days[day] = days[day]?.filter { $0.shiftTypeID != shiftTypeID }
            }
            storage[calendarID] = days
        }
        persist()
    }

    func shiftTypeCounts(inYear year: Int, calendarID: UUID, onlyShiftTypeIDs: Set<UUID>? = nil) -> [UUID: Int] {
        let yearPrefix = String(format: "%04d-", year)
        var counts: [UUID: Int] = [:]
        for (dayKey, entries) in bucket(for: calendarID) where dayKey.hasPrefix(yearPrefix) {
            for entry in entries {
                if let filter = onlyShiftTypeIDs, !filter.contains(entry.shiftTypeID) {
                    continue
                }
                counts[entry.shiftTypeID, default: 0] += 1
            }
        }
        return counts
    }

    func assignments(for calendarID: UUID) -> DayAssignments {
        bucket(for: calendarID)
    }

    func setAssignments(_ assignments: DayAssignments, calendarID: UUID) {
        clearUndo(calendarID: calendarID)
        storage[calendarID] = assignments
        persist()
    }

    func mergeAssignments(_ imported: DayAssignments, calendarID: UUID) {
        clearUndo(calendarID: calendarID)
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
        clearUndo(calendarID: calendarID)
        storage.removeValue(forKey: calendarID)
        persist()
    }

    func replaceAll(_ replacement: [UUID: DayAssignments]) {
        undoStacks.removeAll()
        storage = replacement
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

    private func recordUndo(calendarID: UUID) {
        guard !suppressUndoRecording else { return }

        var stack = undoStacks[calendarID] ?? []
        stack.append(Self.copyAssignments(bucket(for: calendarID)))
        if stack.count > Self.maxUndoSteps {
            stack.removeFirst(stack.count - Self.maxUndoSteps)
        }
        undoStacks[calendarID] = stack
    }

    private func clearUndo(calendarID: UUID) {
        undoStacks.removeValue(forKey: calendarID)
    }

    private static func copyAssignments(_ assignments: DayAssignments) -> DayAssignments {
        assignments.mapValues { entries in
            entries.map { ShiftEntry(id: $0.id, shiftTypeID: $0.shiftTypeID) }
        }
    }
}