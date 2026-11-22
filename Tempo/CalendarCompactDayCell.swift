//
//  CalendarCompactDayCell.swift
//  Tempo
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Celda reducida con la misma lógica visual que la vista mensual.
struct CalendarCompactDayCell: View {
    let date: Date
    let workCalendarID: UUID
    let hostCalendar: WorkCalendar
    let cellSize: CGFloat
    var overlayDotDiameter: CGFloat = 4
    /// 0 = esquinas rectas (p. ej. zoom); >0 redondea la celda.
    var cornerRadius: CGFloat = 0

    @Environment(ShiftStore.self) private var shiftStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore

    private var calendar: Calendar { Calendar.current }

    private var shiftSegments: [(color: Color, initials: String)] {
        let shifts = shiftStore.shifts(for: date, calendarID: workCalendarID, calendar: calendar)
        return shifts.compactMap { entry in
            guard let type = shiftTypeStore.shiftType(id: entry.shiftTypeID) else { return nil }
            return (type.color, type.displayInitials)
        }
    }

    private var overlayDots: [Color] {
        CalendarDayIndicators.overlayDotColors(
            date: date,
            hostCalendar: hostCalendar,
            shiftStore: shiftStore,
            shiftTypeStore: shiftTypeStore,
            calendar: calendar
        )
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var cellHeight: CGFloat { cellSize * 1.65 }

    private var dayNumberColor: Color {
        if let first = shiftSegments.first {
            return initialsColor(for: first.color)
        }
        return .black
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            shiftContent
                .frame(width: cellSize, height: cellHeight)

            Text(dayNumber)
                .font(.system(size: max(7, cellSize * 0.34), weight: .bold))
                .foregroundStyle(dayNumberColor)
                .padding(.top, 2)
                .padding(.trailing, 2)

            if !overlayDots.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    HStack(spacing: max(3, overlayDotDiameter * 0.35)) {
                        ForEach(Array(overlayDots.prefix(3).enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(color)
                                .frame(width: overlayDotDiameter, height: overlayDotDiameter)
                                .overlay {
                                    Circle()
                                        .strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
                                }
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                        }
                    }
                    .padding(.bottom, max(3, overlayDotDiameter * 0.25))
                }
                .frame(width: cellSize, height: cellHeight)
            }
        }
        .frame(width: cellSize, height: cellHeight)
        .background {
            cellBackdrop
                .fill(Color.white)
        }
        .clipShape(cellShape)
        .overlay {
            cellShape.strokeBorder(
                isToday ? Color.accentColor : Color.black.opacity(0.12),
                lineWidth: isToday ? 1.2 : 0.5
            )
        }
    }

    private var cellShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: max(cornerRadius, 0),
            style: .continuous
        )
    }

    private var cellBackdrop: RoundedRectangle {
        cellShape
    }

    @ViewBuilder
    private var shiftContent: some View {
        if shiftSegments.isEmpty {
            Color.white
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shiftSegments.count == 1 {
            miniBand(shiftSegments[0])
        } else {
            VStack(spacing: 0) {
                ForEach(Array(shiftSegments.prefix(4).enumerated()), id: \.offset) { _, segment in
                    miniBand(segment)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func miniBand(_ segment: (color: Color, initials: String)) -> some View {
        segment.color
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func initialsColor(for color: Color) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var white: CGFloat = 0
        uiColor.getWhite(&white, alpha: nil)
        return white < 0.55 ? .white.opacity(0.92) : .black.opacity(0.85)
        #else
        return .black.opacity(0.85)
        #endif
    }
}