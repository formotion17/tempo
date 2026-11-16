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

    init(id: UUID = UUID(), name: String, colorHex: String = ShiftTypeColorOption.sky.rawValue) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex) ?? Color(red: 0.78, green: 0.88, blue: 0.96)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ShiftTypeColorOption.sky.rawValue
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

    func addCalendar(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        calendars.append(WorkCalendar(name: trimmed, colorHex: colorHex))
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