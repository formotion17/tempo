//
//  AppPersistence.swift
//  Tempo
//

import Foundation

enum AppPersistence {
    private static let shiftTypesFileName = "shift_types.json"
    private static let calendarsFileName = "work_calendars.json"
    private static let assignmentsFileName = "shift_assignments.json"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    struct WorkCalendarState: Codable {
        var calendars: [WorkCalendar]
        var selectedCalendarID: UUID
    }

    private static var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("Tempo", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func fileURL(_ name: String) -> URL {
        storageDirectory.appendingPathComponent(name)
    }

    static func loadShiftTypes() -> [ShiftTypeDefinition]? {
        load([ShiftTypeDefinition].self, fileName: shiftTypesFileName)
    }

    static func saveShiftTypes(_ shiftTypes: [ShiftTypeDefinition]) {
        save(shiftTypes, fileName: shiftTypesFileName)
    }

    static func loadWorkCalendarState() -> WorkCalendarState? {
        load(WorkCalendarState.self, fileName: calendarsFileName)
    }

    static func saveWorkCalendarState(_ state: WorkCalendarState) {
        save(state, fileName: calendarsFileName)
    }

    static func loadShiftAssignments() -> [String: [ShiftEntry]]? {
        load([String: [ShiftEntry]].self, fileName: assignmentsFileName)
    }

    static func saveShiftAssignments(_ assignments: [String: [ShiftEntry]]) {
        save(assignments, fileName: assignmentsFileName)
    }

    private static func load<T: Decodable>(_ type: T.Type, fileName: String) -> T? {
        let url = fileURL(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, fileName: String) {
        let url = fileURL(fileName)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}