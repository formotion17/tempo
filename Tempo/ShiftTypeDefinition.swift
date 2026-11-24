//
//  ShiftTypeDefinition.swift
//  Tempo
//

import Foundation
import SwiftUI

struct ShiftTypeDefinition: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var initials: String
    var colorHex: String
    var schedule: String

    init(id: UUID = UUID(), name: String, initials: String, colorHex: String, schedule: String) {
        self.id = id
        self.name = name
        self.initials = initials
        self.colorHex = colorHex
        self.schedule = schedule
    }

    var displayInitials: String {
        let trimmed = initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(name.prefix(2))
        }
        return trimmed
    }

    var color: Color {
        Color(hex: colorHex) ?? Color(red: 0.92, green: 0.92, blue: 0.92)
    }

    var hasSchedule: Bool {
        !schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ShiftTypeColorOption: String, CaseIterable, Identifiable {
    case morningYellow = "#FFEB7A"
    case salmon = "#FFB99A"
    case nightGray = "#7A7A7A"
    case guardRed = "#FF6B6B"
    case olive = "#B5C97A"
    case vacationGreen = "#7DD87D"
    case personalPink = "#F9A8D4"
    case mint = "#B8F2E6"
    case peach = "#FFD6BA"
    case lemon = "#FFF3B0"
    case sky = "#C6E7FF"
    case lilac = "#E2D4F7"
    case rose = "#FFC9DE"
    case sand = "#E8E4D8"
    case sage = "#D4E8C8"

    var id: String { rawValue }

    var color: Color {
        Color(hex: rawValue) ?? .gray.opacity(0.3)
    }
}

@Observable
final class ShiftTypeStore {
    var shiftTypes: [ShiftTypeDefinition]

    init(shiftTypes: [ShiftTypeDefinition]? = nil) {
        if let saved = AppPersistence.loadShiftTypes() {
            self.shiftTypes = saved
            mergeMissingDefaults()
        } else {
            self.shiftTypes = shiftTypes ?? ShiftTypeStore.defaultShiftTypes
            persist()
        }
    }

    private func mergeMissingDefaults() {
        var didChange = false
        for defaultShift in Self.defaultShiftTypes {
            guard !shiftTypes.contains(where: { $0.name == defaultShift.name }) else { continue }
            shiftTypes.append(defaultShift)
            didChange = true
        }
        if didChange {
            persist()
        }
    }

    func addShiftType(_ shiftType: ShiftTypeDefinition) {
        shiftTypes.append(shiftType)
        persist()
    }

    func updateShiftType(_ shiftType: ShiftTypeDefinition) {
        guard let index = shiftTypes.firstIndex(where: { $0.id == shiftType.id }) else { return }
        shiftTypes[index] = shiftType
        persist()
    }

    func deleteShiftType(id: UUID) {
        shiftTypes.removeAll { $0.id == id }
        persist()
    }

    func shiftType(id: UUID) -> ShiftTypeDefinition? {
        shiftTypes.first { $0.id == id }
    }

    func shiftTypes(linkedTo ids: [UUID]) -> [ShiftTypeDefinition] {
        ids.compactMap { id in shiftTypes.first { $0.id == id } }
    }

    func persistShiftTypes() {
        persist()
    }

    func replaceAll(with shiftTypes: [ShiftTypeDefinition]) {
        self.shiftTypes = shiftTypes
        persist()
    }

    private func persist() {
        AppPersistence.saveShiftTypes(shiftTypes)
    }

    private static let defaultShiftTypes: [ShiftTypeDefinition] = [
        ShiftTypeDefinition(
            name: "Mañana",
            initials: "Mañ",
            colorHex: ShiftTypeColorOption.morningYellow.rawValue,
            schedule: "08:00 – 15:00"
        ),
        ShiftTypeDefinition(
            name: "Tarde",
            initials: "Tar",
            colorHex: ShiftTypeColorOption.salmon.rawValue,
            schedule: "14:00 – 21:00"
        ),
        ShiftTypeDefinition(
            name: "Noche",
            initials: "Noc",
            colorHex: ShiftTypeColorOption.nightGray.rawValue,
            schedule: "21:00 – 07:00"
        ),
        ShiftTypeDefinition(
            name: "Guardia",
            initials: "Gua",
            colorHex: ShiftTypeColorOption.guardRed.rawValue,
            schedule: "00:00 – 00:00"
        ),
        ShiftTypeDefinition(
            name: "Día libre",
            initials: "DL",
            colorHex: ShiftTypeColorOption.olive.rawValue,
            schedule: ""
        ),
        ShiftTypeDefinition(
            name: "Vacaciones",
            initials: "V",
            colorHex: ShiftTypeColorOption.vacationGreen.rawValue,
            schedule: ""
        ),
        ShiftTypeDefinition(
            name: "Asuntos Propios",
            initials: "AP",
            colorHex: ShiftTypeColorOption.personalPink.rawValue,
            schedule: ""
        ),
    ]
}

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}