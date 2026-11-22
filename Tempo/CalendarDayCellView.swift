//
//  CalendarDayCellView.swift
//  Tempo
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CalendarDayCellView: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let cellHeight: CGFloat
    let workCalendarID: UUID
    var assignmentsLocked: Bool = false
    let selectedAction: CalendarDayAction
    var onZoomRequest: (() -> Void)? = nil

    @Environment(ShiftStore.self) private var shiftStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(WorkCalendarStore.self) private var calendarStore

    @State private var flipAngle: Double = 0
    @State private var isAnimatingFlip = false

    private var calendar: Calendar { Calendar.current }

    private var shifts: [ShiftEntry] {
        shiftStore.shifts(for: date, calendarID: workCalendarID, calendar: calendar)
    }

    private var shiftSegments: [(color: Color, initials: String)] {
        shifts.compactMap { entry in
            guard let type = shiftTypeStore.shiftType(id: entry.shiftTypeID) else { return nil }
            return (type.color, type.displayInitials)
        }
    }

    private var overlayBubbles: [(color: Color, label: String)] {
        guard let host = calendarStore.calendar(id: workCalendarID), !host.isImported else { return [] }
        var items: [(Color, String)] = []
        for overlay in host.overlays {
            let sourceShifts = shiftStore.shifts(for: date, calendarID: overlay.sourceCalendarID, calendar: calendar)
            for entry in sourceShifts where overlay.includes(shiftTypeID: entry.shiftTypeID) {
                let appearance = overlay.bubbleAppearance(for: entry.shiftTypeID, shiftTypeStore: shiftTypeStore)
                items.append(appearance)
            }
        }
        return items
    }

    private var isToday: Bool {
        isInDisplayedMonth && calendar.isDateInToday(date)
    }

    private var isAdjacentMonthDay: Bool {
        !isInDisplayedMonth
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var normalizedFlipAngle: Double {
        var angle = flipAngle.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return angle
    }

    private var isShowingFront: Bool {
        normalizedFlipAngle <= 90 || normalizedFlipAngle >= 270
    }

    var body: some View {
        ZStack {
            cardContent
                .opacity(isShowingFront ? 1 : 0)
                .rotation3DEffect(
                    .degrees(flipAngle),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.42
                )

            cardContent
                .opacity(isShowingFront ? 0 : 1)
                .rotation3DEffect(
                    .degrees(flipAngle - 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.42
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: cellHeight)
        .opacity(isAdjacentMonthDay ? 0.34 : 1)
        .saturation(isAdjacentMonthDay ? 0.35 : 1)
        .blur(radius: isAdjacentMonthDay ? 0.35 : 0)
        .allowsHitTesting(isInDisplayedMonth && !isAnimatingFlip && !assignmentsLocked)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            applySelectedAction()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard isInDisplayedMonth, !isAnimatingFlip, let onZoomRequest else { return }
                onZoomRequest()
            }
        )
    }

    private var cardContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                dayNumberLabel
                shiftArea
            }

            if !overlayBubbles.isEmpty {
                overlayBubblesRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAdjacentMonthDay ? Color.gray.opacity(0.12) : Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    borderColor,
                    lineWidth: isToday ? 1.5 : 0.75
                )
        }
    }

    private var borderColor: Color {
        if isToday { return Color.accentColor }
        if isAdjacentMonthDay { return Color.gray.opacity(0.28) }
        return Color.black.opacity(0.35)
    }

    private var dayNumberLabel: some View {
        Text(dayNumber)
            .font(.system(size: 10, weight: isToday ? .bold : .semibold))
            .foregroundStyle(isAdjacentMonthDay ? Color.gray.opacity(0.55) : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(isAdjacentMonthDay ? Color.gray.opacity(0.22) : Color.black)
    }

    @ViewBuilder
    private var shiftArea: some View {
        if shiftSegments.isEmpty {
            Color.white
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shiftSegments.count == 1 {
            shiftBand(shiftSegments[0])
        } else {
            VStack(spacing: 0) {
                ForEach(Array(shiftSegments.enumerated()), id: \.offset) { _, segment in
                    shiftBand(segment)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func initialsColor(for color: Color) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var white: CGFloat = 0
        uiColor.getWhite(&white, alpha: nil)
        return white < 0.55 ? .white.opacity(0.92) : .black.opacity(0.75)
        #else
        return .black.opacity(0.75)
        #endif
    }

    private var overlayBubblesRow: some View {
        HStack(spacing: 3) {
            ForEach(Array(overlayBubbles.enumerated()), id: \.offset) { _, bubble in
                Text(bubble.label)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(bubbleForeground(on: bubble.color))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background {
                        Capsule(style: .continuous)
                            .fill(bubble.color)
                            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    }
            }
        }
        .padding(.bottom, 3)
        .padding(.horizontal, 3)
        .allowsHitTesting(false)
    }

    private func bubbleForeground(on color: Color) -> Color {
        initialsColor(for: color)
    }

    private func shiftBand(_ segment: (color: Color, initials: String)) -> some View {
        ZStack {
            segment.color
            Text(segment.initials)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(initialsColor(for: segment.color))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performFlipThenApply(_ apply: @escaping () -> Void) {
        guard !isAnimatingFlip else { return }
        isAnimatingFlip = true

        let startAngle = normalizedFlipAngle
        let targetAngle = startAngle + 180
        let duration = 0.46

        withAnimation(.easeInOut(duration: duration)) {
            flipAngle = targetAngle
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int((duration / 2) * 1000)))
            apply()
            try? await Task.sleep(for: .milliseconds(Int((duration / 2) * 1000)))
            flipAngle = targetAngle.truncatingRemainder(dividingBy: 360)
            isAnimatingFlip = false
        }
    }

    private func applySelectedAction() {
        guard isInDisplayedMonth, !isAnimatingFlip else { return }

        switch selectedAction {
        case .none:
            break
        case .clearDay:
            guard !shifts.isEmpty else { return }
            performFlipThenApply {
                shiftStore.clearDay(on: date, calendarID: workCalendarID, calendar: calendar)
            }
        case .applyShift(let shiftTypeID):
            if shifts.contains(where: { $0.shiftTypeID == shiftTypeID }) {
                performFlipThenApply {
                    shiftStore.removeShift(shiftTypeID: shiftTypeID, on: date, calendarID: workCalendarID, calendar: calendar)
                }
            } else if shifts.count < ShiftStore.maxShiftsPerDay {
                performFlipThenApply {
                    shiftStore.addShift(shiftTypeID: shiftTypeID, on: date, calendarID: workCalendarID, calendar: calendar)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var store = ShiftStore()
    let typeStore = ShiftTypeStore()
    CalendarDayCellView(
        date: .now,
        isInDisplayedMonth: true,
        cellHeight: 88,
        workCalendarID: UUID(),
        selectedAction: .none
    )
    .padding(8)
    .background(Color(.systemGroupedBackground))
    .environment(store)
    .environment(typeStore)
    .environment(WorkCalendarStore())
}