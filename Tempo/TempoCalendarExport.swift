//
//  TempoCalendarExport.swift
//  Tempo
//

import Foundation

enum TempoExportKind: String, Codable {
    case calendar = "calendar"
    case database = "database"
}

/// Copia completa de la app (calendarios, turnos, asignaciones y estado).
struct TempoDatabaseExportFile: Codable, Identifiable {
    static let currentSchemaVersion = 2
    static let kind = TempoExportKind.database

    let schemaVersion: Int
    let exportedAt: Date
    let exportKind: TempoExportKind
    let shiftTypes: [ShiftTypeDefinition]
    let calendars: [WorkCalendar]
    let selectedCalendarID: UUID
    let assignmentsByCalendarID: [String: DayAssignments]

    var id: String { "database-" + exportedAt.ISO8601Format() }

    init(
        shiftTypes: [ShiftTypeDefinition],
        calendars: [WorkCalendar],
        selectedCalendarID: UUID,
        assignmentsByCalendarID: [String: DayAssignments],
        exportedAt: Date = .now
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.exportKind = Self.kind
        self.shiftTypes = shiftTypes
        self.calendars = calendars
        self.selectedCalendarID = selectedCalendarID
        self.assignmentsByCalendarID = assignmentsByCalendarID
    }
}

/// Formato de exportación/importación de calendarios Tempo.
struct TempoCalendarExportFile: Codable, Identifiable {
    static let currentSchemaVersion = 1

    /// Versión del esquema JSON (permite evolucionar el formato).
    let schemaVersion: Int

    /// Momento de exportación (ISO-8601).
    let exportedAt: Date

    /// Calendario exportado (identidad y presentación).
    let calendar: WorkCalendar

    /// Catálogo de tipos de turno referenciados en las asignaciones.
    let shiftTypes: [ShiftTypeDefinition]

    /// Asignaciones por día (`YYYY-MM-DD` → turnos en ese día).
    let assignmentsByDay: [String: [ShiftEntry]]
    let exportKind: TempoExportKind?
    /// Calendarios superpuestos empaquetados (mismas IDs que en el origen).
    let companionCalendars: [WorkCalendar]
    /// Asignaciones de cada calendario superpuesto (clave = UUID del calendario).
    let companionAssignmentsByCalendarID: [String: DayAssignments]

    var id: String { calendar.id.uuidString + exportedAt.ISO8601Format() }

    init(
        calendar: WorkCalendar,
        shiftTypes: [ShiftTypeDefinition],
        assignmentsByDay: [String: [ShiftEntry]],
        companionCalendars: [WorkCalendar] = [],
        companionAssignmentsByCalendarID: [String: DayAssignments] = [:],
        exportedAt: Date = .now
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.calendar = calendar
        self.shiftTypes = shiftTypes
        self.assignmentsByDay = assignmentsByDay
        self.exportKind = .calendar
        self.companionCalendars = companionCalendars
        self.companionAssignmentsByCalendarID = companionAssignmentsByCalendarID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        calendar = try container.decode(WorkCalendar.self, forKey: .calendar)
        shiftTypes = try container.decode([ShiftTypeDefinition].self, forKey: .shiftTypes)
        assignmentsByDay = try container.decode([String: [ShiftEntry]].self, forKey: .assignmentsByDay)
        exportKind = try container.decodeIfPresent(TempoExportKind.self, forKey: .exportKind)
        companionCalendars = try container.decodeIfPresent([WorkCalendar].self, forKey: .companionCalendars) ?? []
        companionAssignmentsByCalendarID =
            try container.decodeIfPresent([String: DayAssignments].self, forKey: .companionAssignmentsByCalendarID) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, calendar, shiftTypes, assignmentsByDay, exportKind
        case companionCalendars, companionAssignmentsByCalendarID
    }
}

enum TempoImportPayload: Identifiable {
    case calendar(TempoCalendarExportFile)
    case database(TempoDatabaseExportFile)

    var id: String {
        switch self {
        case .calendar(let file): file.id
        case .database(let file): file.id
        }
    }
}

enum TempoExportPayload: Identifiable {
    case calendar(TempoCalendarExportFile)
    case database(TempoDatabaseExportFile)

    var id: String {
        switch self {
        case .calendar(let file): file.id
        case .database(let file): file.id
        }
    }
}

enum CalendarExportService {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func exportableShiftTypeIDs(
        for calendar: WorkCalendar,
        assignments: DayAssignments
    ) -> [UUID] {
        let catalogIDs: [UUID] = {
            if !calendar.bundledShiftTypeIDs.isEmpty {
                return calendar.bundledShiftTypeIDs
            }
            if !calendar.shiftTypeIDs.isEmpty {
                return calendar.shiftTypeIDs
            }
            return []
        }()

        var ids = Set(catalogIDs)
        let usedTypeIDs = Set(assignments.values.flatMap { $0.map(\.shiftTypeID) })
        ids.formUnion(usedTypeIDs)
        return catalogIDs + usedTypeIDs.filter { !catalogIDs.contains($0) }
    }

    static func buildExport(
        calendar: WorkCalendar,
        shiftTypes: [ShiftTypeDefinition],
        assignments: DayAssignments,
        includedShiftTypeIDs: Set<UUID>,
        includedOverlaySourceIDs: Set<UUID>,
        calendarStore: WorkCalendarStore,
        shiftStore: ShiftStore
    ) -> TempoCalendarExportFile {
        let filteredAssignments = filterAssignments(assignments, shiftTypeIDs: includedShiftTypeIDs)

        let catalogIDs = exportableShiftTypeIDs(for: calendar, assignments: assignments)
            .filter { includedShiftTypeIDs.contains($0) }

        var exportedTypes = catalogIDs.compactMap { id in shiftTypes.first { $0.id == id } }
        let usedTypeIDs = Set(filteredAssignments.values.flatMap { $0.map(\.shiftTypeID) })
        for id in usedTypeIDs where !exportedTypes.contains(where: { $0.id == id }) {
            if let type = shiftTypes.first(where: { $0.id == id }) {
                exportedTypes.append(type)
            }
        }

        var exportCalendar = calendar
        exportCalendar.shiftTypeIDs = exportCalendar.shiftTypeIDs.filter { includedShiftTypeIDs.contains($0) }
        exportCalendar.overlays = exportCalendar.overlays.filter { includedOverlaySourceIDs.contains($0.sourceCalendarID) }

        if exportCalendar.bundledShiftTypeIDs.isEmpty && !exportCalendar.isImported {
            exportCalendar.bundledShiftTypeIDs = catalogIDs
        } else {
            exportCalendar.bundledShiftTypeIDs = exportCalendar.bundledShiftTypeIDs.filter {
                includedShiftTypeIDs.contains($0)
            }
        }

        var companionCalendars: [WorkCalendar] = []
        var companionAssignments: [String: DayAssignments] = [:]

        for overlay in calendar.overlays where includedOverlaySourceIDs.contains(overlay.sourceCalendarID) {
            guard let source = calendarStore.calendar(id: overlay.sourceCalendarID) else { continue }
            let sourceAssignments = shiftStore.assignments(for: source.id)
            let overlayShiftIDs = Set(overlay.includedShiftTypeIDs)
            let filteredSource = filterAssignments(sourceAssignments, shiftTypeIDs: overlayShiftIDs)

            companionCalendars.append(source)
            companionAssignments[source.id.uuidString] = filteredSource

            let companionTypeIDs = source.overlaySourceShiftTypeIDs.filter { overlayShiftIDs.contains($0) }
            for id in companionTypeIDs where !exportedTypes.contains(where: { $0.id == id }) {
                if let type = shiftTypes.first(where: { $0.id == id }) {
                    exportedTypes.append(type)
                }
            }
        }

        return TempoCalendarExportFile(
            calendar: exportCalendar,
            shiftTypes: exportedTypes,
            assignmentsByDay: filteredAssignments,
            companionCalendars: companionCalendars,
            companionAssignmentsByCalendarID: companionAssignments
        )
    }

    private static func filterAssignments(
        _ assignments: DayAssignments,
        shiftTypeIDs: Set<UUID>
    ) -> DayAssignments {
        assignments.compactMapValues { entries in
            let filtered = entries.filter { shiftTypeIDs.contains($0.shiftTypeID) }
            return filtered.isEmpty ? nil : filtered
        }
    }

    static func encode(_ export: TempoCalendarExportFile) throws -> Data {
        try encoder.encode(export)
    }

    static func fileName(for calendar: WorkCalendar) -> String {
        let safeName = calendar.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "Tempo-\(safeName).json"
    }

    static func writeTemporaryFile(for export: TempoCalendarExportFile) throws -> URL {
        let data = try encode(export)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: export.calendar))
        try data.write(to: url, options: .atomic)
        return url
    }

    static func buildDatabaseExport(
        shiftTypes: [ShiftTypeDefinition],
        calendars: [WorkCalendar],
        selectedCalendarID: UUID,
        shiftStore: ShiftStore
    ) -> TempoDatabaseExportFile {
        var assignments: [String: DayAssignments] = [:]
        for calendar in calendars {
            assignments[calendar.id.uuidString] = shiftStore.assignments(for: calendar.id)
        }
        return TempoDatabaseExportFile(
            shiftTypes: shiftTypes,
            calendars: calendars,
            selectedCalendarID: selectedCalendarID,
            assignmentsByCalendarID: assignments
        )
    }

    static func encodeDatabase(_ export: TempoDatabaseExportFile) throws -> Data {
        try encoder.encode(export)
    }

    static func databaseFileName() -> String {
        "Tempo-backup.json"
    }

    static func writeTemporaryDatabaseFile(for export: TempoDatabaseExportFile) throws -> URL {
        let data = try encodeDatabase(export)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(databaseFileName())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writeTemporaryFile(for payload: TempoExportPayload) throws -> URL {
        switch payload {
        case .calendar(let export):
            try writeTemporaryFile(for: export)
        case .database(let export):
            try writeTemporaryDatabaseFile(for: export)
        }
    }
}

enum CalendarImportService {
    enum ImportError: LocalizedError {
        case unreadableFile
        case unsupportedSchema(version: Int)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unreadableFile:
                "No se pudo leer el archivo seleccionado."
            case .unsupportedSchema(let version):
                "Versión de archivo no compatible (v\(version))."
            case .invalidData:
                "El archivo no tiene un formato Tempo válido."
            }
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func loadData(from url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        guard url.isFileURL else { throw ImportError.unreadableFile }
        return try Data(contentsOf: url)
    }

    static func decodePayload(from url: URL) throws -> TempoImportPayload {
        let data = try loadData(from: url)
        if let database = try? decoder.decode(TempoDatabaseExportFile.self, from: data),
           database.exportKind == .database {
            guard database.schemaVersion <= TempoDatabaseExportFile.currentSchemaVersion else {
                throw ImportError.unsupportedSchema(version: database.schemaVersion)
            }
            return .database(database)
        }

        let export = try decoder.decode(TempoCalendarExportFile.self, from: data)
        guard export.schemaVersion <= TempoCalendarExportFile.currentSchemaVersion else {
            throw ImportError.unsupportedSchema(version: export.schemaVersion)
        }
        return .calendar(export)
    }

    static func decode(from url: URL) throws -> TempoCalendarExportFile {
        switch try decodePayload(from: url) {
        case .calendar(let export):
            return export
        case .database:
            throw ImportError.invalidData
        }
    }

    static func uniqueCalendarName(_ proposed: String, existing: [WorkCalendar]) -> String {
        let base = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return "Calendario importado" }
        let names = Set(existing.map(\.name))
        guard names.contains(base) else { return base }
        var suffix = 2
        while names.contains("\(base) (\(suffix))") { suffix += 1 }
        return "\(base) (\(suffix))"
    }
}