//
//  CalendarsView.swift
//  Tempo
//

import SwiftUI

struct CalendarsView: View {
    @Binding var selectedAction: CalendarDayAction

    private var calendar: Calendar { Calendar.current }

    @State private var displayedMonth = Date()

    private static let monthHeaderHeight: CGFloat = 28
    private static let weekdayHeaderHeight: CGFloat = 18
    private static let sectionSpacing: CGFloat = 4
    private static let gridRowSpacing: CGFloat = 6
    private static let fixedWeekRowCount = MonthCalendarLogic.fixedWeekRowCount

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_ES")))
    }

    private var gridDays: [MonthGridDay] {
        MonthCalendarLogic.monthGridDays(for: displayedMonth, calendar: calendar)
    }

    var body: some View {
        VStack(spacing: Self.sectionSpacing) {
            monthHeader
                .frame(height: Self.monthHeaderHeight)

            weekdayHeader
                .frame(height: Self.weekdayHeaderHeight)

            GeometryReader { geometry in
                let totalRowSpacing = Self.gridRowSpacing * CGFloat(Self.fixedWeekRowCount - 1)
                let cellHeight = max(
                    (geometry.size.height - totalRowSpacing) / CGFloat(Self.fixedWeekRowCount),
                    1
                )

                daysGrid(cellHeight: cellHeight)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .clipped()
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mes anterior")

            Spacer()

            Text(monthTitle.capitalized)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .animation(.snappy, value: monthTitle)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mes siguiente")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(MonthCalendarLogic.weekdaySymbols(calendar: calendar), id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func daysGrid(cellHeight: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: Self.gridRowSpacing) {
            ForEach(gridDays) { gridDay in
                CalendarDayCellView(
                    date: gridDay.date,
                    isInDisplayedMonth: gridDay.isInDisplayedMonth,
                    cellHeight: cellHeight,
                    selectedAction: selectedAction
                )
            }
        }
        .animation(.snappy, value: displayedMonth)
    }

    private func changeMonth(by offset: Int) {
        withAnimation(.snappy) {
            displayedMonth = MonthCalendarLogic.shiftedMonth(from: displayedMonth, by: offset, calendar: calendar)
        }
    }
}

#Preview {
    @Previewable @State var action: CalendarDayAction = .none
    CalendarsView(selectedAction: $action)
        .environment(ShiftStore())
        .environment(ShiftTypeStore())
}