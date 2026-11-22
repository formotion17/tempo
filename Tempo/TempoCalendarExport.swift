//
//  TempoCalendarExport.swift
//  Tempo
//

import Foundation

/// Formato de exportación/importación de calendarios Tempo.
struct TempoCalendarExportFile: Codable {
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

    init(
        calendar: WorkCalendar,
        shiftTypes: [ShiftTypeDefinition],
        assignmentsByDay: [String: [ShiftEntry]],
        exportedAt: Date = .now
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.calendar = calendar
        self.shiftTypes = shiftTypes
        self.assignmentsByDay = assignmentsByDay
    }
}

enum CalendarExportService {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func buildExport(
        calendar: WorkCalendar,
        shiftTypes: [ShiftTypeDefinition],
        assignments: DayAssignments
    ) -> TempoCalendarExportFile {
        let catalogIDs: [UUID] = {
            if !calendar.bundledShiftTypeIDs.isEmpty {
                return calendar.bundledShiftTypeIDs
            }
            if !calendar.shiftTypeIDs.isEmpty {
                return calendar.shiftTypeIDs
            }
            return shiftTypes.map(\.id)
        }()

        var exportedTypes = catalogIDs.compactMap { id in shiftTypes.first { $0.id == id } }
        let usedTypeIDs = Set(assignments.values.flatMap { $0.map(\.shiftTypeID) })
        for id in usedTypeIDs where !exportedTypes.contains(where: { $0.id == id }) {
            if let type = shiftTypes.first(where: { $0.id == id }) {
                exportedTypes.append(type)
            }
        }

        var exportCalendar = calendar
        if exportCalendar.bundledShiftTypeIDs.isEmpty && !exportCalendar.isImported {
            exportCalendar.bundledShiftTypeIDs = catalogIDs
        }

        return TempoCalendarExportFile(
            calendar: exportCalendar,
            shiftTypes: exportedTypes,
            assignmentsByDay: assignments
        )
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

    static func decode(from url: URL) throws -> TempoCalendarExportFile {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            throw ImportError.unreadableFile
        }

        let export = try decoder.decode(TempoCalendarExportFile.self, from: data)
        guard export.schemaVersion <= TempoCalendarExportFile.currentSchemaVersion else {
            throw ImportError.unsupportedSchema(version: export.schemaVersion)
        }
        return export
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