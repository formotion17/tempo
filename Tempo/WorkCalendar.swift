//
//  WorkCalendar.swift
//  Tempo
//

import Foundation
import SwiftUI

struct WorkCalendar: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String
    /// Turnos visibles en la paleta de este calendario.
    var shiftTypeIDs: [UUID]
    /// Turnos incluidos al importar (no se comparten con otros calendarios).
    var bundledShiftTypeIDs: [UUID]
    var isImported: Bool
    /// Calendarios importados superpuestos (solo en calendarios locales).
    var overlays: [CalendarOverlay]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = ShiftTypeColorOption.sky.rawValue,
        shiftTypeIDs: [UUID] = [],
        bundledShiftTypeIDs: [UUID] = [],
        isImported: Bool = false,
        overlays: [CalendarOverlay] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shiftTypeIDs = shiftTypeIDs
        self.bundledShiftTypeIDs = bundledShiftTypeIDs
        self.isImported = isImported
        self.overlays = overlays
    }

    var color: Color {
        Color(hex: colorHex) ?? Color(red: 0.78, green: 0.88, blue: 0.96)
    }

    var listDisplayName: String {
        isImported ? "\(name) (importado)" : name
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, shiftTypeIDs, bundledShiftTypeIDs, isImported, overlays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ShiftTypeColorOption.sky.rawValue
        shiftTypeIDs = try container.decodeIfPresent([UUID].self, forKey: .shiftTypeIDs) ?? []
        bundledShiftTypeIDs = try container.decodeIfPresent([UUID].self, forKey: .bundledShiftTypeIDs) ?? []
        isImported = try container.decodeIfPresent(Bool.self, forKey: .isImported) ?? false
        overlays = try container.decodeIfPresent([CalendarOverlay].self, forKey: .overlays) ?? []
    }
}

@Observable
final class WorkCalendarStore {
    var calendars: [WorkCalendar]
    var selectedCalendarID: UUID

    init(
        calendars: [WorkCalendar]? = nil,
        selectedCalendarID: UUID? = nil
    ) {
        if let saved = AppPersistence.loadWorkCalendarState() {
            self.calendars = saved.calendars
            self.selectedCalendarID = saved.selectedCalendarID
            normalizeCalendarColorsIfNeeded()
        } else {
            let defaults = calendars ?? WorkCalendarStore.defaultCalendars
            self.calendars = defaults
            self.selectedCalendarID = selectedCalendarID ?? defaults[0].id
            persist()
        }
    }

    var selectedCalendar: WorkCalendar {
        calendars.first { $0.id == selectedCalendarID } ?? calendars[0]
    }

    func selectCalendar(_ calendar: WorkCalendar) {
        selectedCalendarID = calendar.id
        persist()
    }

    func addCalendar(name: String, colorHex: String, shiftTypeIDs: [UUID] = []) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        calendars.append(WorkCalendar(name: trimmed, colorHex: colorHex, shiftTypeIDs: shiftTypeIDs))
        persist()
    }

    func addCalendar(_ calendar: WorkCalendar) {
        calendars.append(calendar)
        persist()
    }

    func updateCalendar(_ calendar: WorkCalendar) {
        guard let index = calendars.firstIndex(where: { $0.id == calendar.id }) else { return }
        calendars[index] = calendar
        persist()
    }

    func updateCalendarName(id: UUID, name: String) {
        guard let index = calendars.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        calendars[index].name = trimmed
        persist()
    }

    func deleteCalendar(id: UUID) {
        guard calendars.count > 1 else { return }
        calendars.removeAll { $0.id == id }
        if selectedCalendarID == id {
            selectedCalendarID = calendars[0].id
        }
        persist()
    }

    func removeShiftTypeFromAllCalendars(shiftTypeID: UUID) {
        var didChange = false
        for index in calendars.indices {
            let before = calendars[index].shiftTypeIDs.count
            calendars[index].shiftTypeIDs.removeAll { $0 == shiftTypeID }
            if calendars[index].shiftTypeIDs.count != before {
                didChange = true
            }
        }
        if didChange { persist() }
    }

    /// Si un calendario no tiene turnos asignados aún, enlaza todos los disponibles (migración).
    func linkAllShiftTypesIfEmpty(_ allShiftTypeIDs: [UUID]) {
        guard !allShiftTypeIDs.isEmpty else { return }
        var didChange = false
        for index in calendars.indices where !calendars[index].isImported && calendars[index].shiftTypeIDs.isEmpty {
            calendars[index].shiftTypeIDs = allShiftTypeIDs
            didChange = true
        }
        if didChange { persist() }
    }

    /// Turnos reservados por calendarios importados (no se ofrecen al enlazar en calendarios locales).
    func bundledShiftTypeIDsReserved() -> Set<UUID> {
        Set(calendars.filter(\.isImported).flatMap(\.bundledShiftTypeIDs))
    }

    func calendar(id: UUID) -> WorkCalendar? {
        calendars.first { $0.id == id }
    }

    func removeOverlaysReferencing(sourceCalendarID: UUID) {
        var didChange = false
        for index in calendars.indices {
            let before = calendars[index].overlays.count
            calendars[index].overlays.removeAll { $0.sourceCalendarID == sourceCalendarID }
            if calendars[index].overlays.count != before {
                didChange = true
            }
        }
        if didChange { persist() }
    }

    func importedCalendars(excluding hostID: UUID? = nil) -> [WorkCalendar] {
        calendars.filter { calendar in
            calendar.isImported && calendar.id != hostID
        }
    }

    /// Cualquier otro calendario puede servir de capa superpuesta (típicamente importados).
    func overlaySourceCandidates(excluding hostID: UUID?, alreadyUsed: Set<UUID>) -> [WorkCalendar] {
        calendars.filter { calendar in
            calendar.id != hostID && !alreadyUsed.contains(calendar.id)
        }
    }

    private func normalizeCalendarColorsIfNeeded() {
        let palette = ShiftTypeColorOption.allCases.map(\.rawValue)
        var didChange = false
        for index in calendars.indices where calendars[index].colorHex.isEmpty {
            calendars[index].colorHex = palette[index % palette.count]
            didChange = true
        }
        if didChange { persist() }
    }

    private func persist() {
        AppPersistence.saveWorkCalendarState(
            AppPersistence.WorkCalendarState(
                calendars: calendars,
                selectedCalendarID: selectedCalendarID
            )
        )
    }

    func persistCalendars() {
        persist()
    }

    func calendarNameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                self.calendars.first(where: { $0.id == id })?.name ?? ""
            },
            set: { newValue in
                self.updateCalendarName(id: id, name: newValue)
            }
        )
    }

    private static let defaultCalendars: [WorkCalendar] = [
        WorkCalendar(name: "Principal", colorHex: ShiftTypeColorOption.sky.rawValue),
        WorkCalendar(name: "Urgencias", colorHex: ShiftTypeColorOption.guardRed.rawValue),
        WorkCalendar(name: "Consultas", colorHex: ShiftTypeColorOption.mint.rawValue),
        WorkCalendar(name: "Pediatría", colorHex: ShiftTypeColorOption.peach.rawValue),
        WorkCalendar(name: "Quirófano", colorHex: ShiftTypeColorOption.lilac.rawValue),
        WorkCalendar(name: "Guardias", colorHex: ShiftTypeColorOption.nightGray.rawValue),
        WorkCalendar(name: "Formación", colorHex: ShiftTypeColorOption.lemon.rawValue),
    ]
}