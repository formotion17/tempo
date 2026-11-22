//
//  CalendarOverlay.swift
//  Tempo
//

import Foundation
import SwiftUI

struct OverlayShiftAppearance: Codable, Hashable {
    var colorHex: String
    var label: String
}

struct CalendarOverlay: Identifiable, Hashable, Codable {
    let id: UUID
    var sourceCalendarID: UUID
    var includedShiftTypeIDs: [UUID]
    var shiftAppearances: [UUID: OverlayShiftAppearance]

    init(
        id: UUID = UUID(),
        sourceCalendarID: UUID,
        includedShiftTypeIDs: [UUID] = [],
        shiftAppearances: [UUID: OverlayShiftAppearance] = [:]
    ) {
        self.id = id
        self.sourceCalendarID = sourceCalendarID
        self.includedShiftTypeIDs = includedShiftTypeIDs
        self.shiftAppearances = shiftAppearances
    }

    func includes(shiftTypeID: UUID) -> Bool {
        includedShiftTypeIDs.contains(shiftTypeID)
    }

    func bubbleAppearance(
        for shiftTypeID: UUID,
        shiftTypeStore: ShiftTypeStore
    ) -> (color: Color, label: String) {
        if let custom = shiftAppearances[shiftTypeID] {
            let color = Color(hex: custom.colorHex) ?? Color.gray.opacity(0.5)
            let label = custom.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty {
                return (color, label)
            }
        }
        if let type = shiftTypeStore.shiftType(id: shiftTypeID) {
            return (type.color, type.displayInitials)
        }
        return (Color.gray.opacity(0.5), "?")
    }

    static func makeDefault(source: WorkCalendar, shiftTypeStore: ShiftTypeStore) -> CalendarOverlay {
        let shiftIDs = source.overlaySourceShiftTypeIDs
        var appearances: [UUID: OverlayShiftAppearance] = [:]
        for shiftID in shiftIDs {
            guard let type = shiftTypeStore.shiftType(id: shiftID) else { continue }
            appearances[shiftID] = OverlayShiftAppearance(
                colorHex: type.colorHex,
                label: type.displayInitials
            )
        }
        return CalendarOverlay(
            sourceCalendarID: source.id,
            includedShiftTypeIDs: shiftIDs,
            shiftAppearances: appearances
        )
    }

    mutating func ensureAppearance(for shiftType: ShiftTypeDefinition) {
        guard shiftAppearances[shiftType.id] == nil else { return }
        shiftAppearances[shiftType.id] = OverlayShiftAppearance(
            colorHex: shiftType.colorHex,
            label: shiftType.displayInitials
        )
    }
}

extension WorkCalendar {
    var overlaySourceShiftTypeIDs: [UUID] {
        if !bundledShiftTypeIDs.isEmpty {
            return bundledShiftTypeIDs
        }
        return shiftTypeIDs
    }
}