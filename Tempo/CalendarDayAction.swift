//
//  CalendarDayAction.swift
//  Tempo
//

import Foundation

enum CalendarDayAction: Equatable {
    case none
    case clearDay
    case applyShift(UUID)
}