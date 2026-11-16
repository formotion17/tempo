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

@Observable
final class ShiftStore {
    private var storage: [String: [ShiftEntry]] = [:]

    init() {
        if let saved = AppPersistence.loadShiftAssignments() {
            storage = saved
        }
    }

    func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return "\(date.timeIntervalSince1970)"
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func shifts(for date: Date, calendar: Calendar = .current) -> [ShiftEntry] {
        storage[dayKey(for: date, calendar: calendar)] ?? []
    }

    static let maxShiftsPerDay = 4

    func addShift(shiftTypeID: UUID, on date: Date, calendar: Calendar = .current) {
        let key = dayKey(for: date, calendar: calendar)
        var entries = storage[key] ?? []
        guard !entries.contains(where: { $0.shiftTypeID == shiftTypeID }) else { return }
        guard entries.count < Self.maxShiftsPerDay else { return }
        entries.append(ShiftEntry(shiftTypeID: shiftTypeID))
        storage[key] = entries
        persist()
    }

    func clearDay(on date: Date, calendar: Calendar = .current) {
        let key = dayKey(for: date, calendar: calendar)
        storage[key] = []
        persist()
    }

    func removeShift(id: UUID, on date: Date, calendar: Calendar = .current) {
        let key = dayKey(for: date, calendar: calendar)
        storage[key] = storage[key]?.filter { $0.id != id }
        persist()
    }

    func removeShift(shiftTypeID: UUID, on date: Date, calendar: Calendar = .current) {
        let key = dayKey(for: date, calendar: calendar)
        storage[key] = storage[key]?.filter { $0.shiftTypeID != shiftTypeID }
        persist()
    }

    func removeShifts(shiftTypeID: UUID) {
        for key in storage.keys {
            storage[key] = storage[key]?.filter { $0.shiftTypeID != shiftTypeID }
        }
        persist()
    }

    func persistAssignments() {
        persist()
    }

    private func persist() {
        AppPersistence.saveShiftAssignments(storage)
    }
}