//
//  CalendarYearOverviewView.swift
//  Tempo
//

import SwiftUI

struct CalendarYearOverviewView: View {
    @Environment(WorkCalendarStore.self) private var calendarStore

    let year: Int
    let onDayZoom: (Date) -> Void

    private var calendar: Calendar { Calendar.current }

    private var yearMonths: [Date] {
        MonthCalendarLogic.months(inYear: year, calendar: calendar)
    }

    private var hostCalendar: WorkCalendar {
        calendarStore.selectedCalendar
    }

    var body: some View {
        GeometryReader { geometry in
            let outerPadding: CGFloat = 4
            let columnSpacing: CGFloat = 14
            let monthRowSpacing: CGFloat = 8
            let usableWidth = max(geometry.size.width - outerPadding * 2 - columnSpacing, 200)
            let monthWidth = usableWidth / 2
            let monthInnerPadding: CGFloat = 6
            let dayCellSize = min(max((monthWidth - monthInnerPadding) / 7, 18), 34)
            let yearDayGap: CGFloat = 1
            let yearDayCorner = max(3, dayCellSize * 0.14)
            let monthCardHeight = monthCardHeight(for: dayCellSize, dayGap: yearDayGap)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: columnSpacing),
                        GridItem(.flexible(), spacing: columnSpacing),
                    ],
                    spacing: monthRowSpacing
                ) {
                    ForEach(yearMonths, id: \.self) { month in
                        YearMonthMiniView(
                            month: month,
                            hostCalendar: hostCalendar,
                            calendarID: hostCalendar.id,
                            dayCellSize: dayCellSize,
                            dayGap: yearDayGap,
                            dayCornerRadius: yearDayCorner,
                            onDayTap: onDayZoom
                        )
                        .frame(height: monthCardHeight)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func monthCardHeight(for dayCellSize: CGFloat, dayGap: CGFloat) -> CGFloat {
        let dayCellHeight = dayCellSize * 1.65
        let titleBlock: CGFloat = 22
        let weekdayRow: CGFloat = 14
        let gridHeight = 6 * dayCellHeight + 5 * dayGap
        let padding: CGFloat = 8
        return titleBlock + weekdayRow + gridHeight + padding
    }
}

private struct YearMonthMiniView: View {
    let month: Date
    let hostCalendar: WorkCalendar
    let calendarID: UUID
    let dayCellSize: CGFloat
    let dayGap: CGFloat
    let dayCornerRadius: CGFloat
    let onDayTap: (Date) -> Void

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        month.formatted(.dateTime.month(.wide).locale(Locale(identifier: "es_ES"))).capitalized
    }

    private var weeks: [[Date?]] {
        MonthCalendarLogic.monthDaySlotsFixedRows(for: month, calendar: calendar)
    }

    private var weekdayInitials: [String] {
        MonthCalendarLogic.spanishWeekdayInitials(calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthTitle)
                .font(.system(size: max(13, dayCellSize * 0.62), weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(weekdayInitials, id: \.self) { initial in
                    Text(initial)
                        .font(.system(size: max(8, dayCellSize * 0.38), weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: dayCellSize, height: 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: dayGap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: dayGap) {
                        ForEach(0..<7, id: \.self) { index in
                            if let date = week[index] {
                                CalendarCompactDayCell(
                                    date: date,
                                    workCalendarID: calendarID,
                                    hostCalendar: hostCalendar,
                                    cellSize: dayCellSize,
                                    cornerRadius: dayCornerRadius
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onDayTap(date)
                                }
                            } else {
                                Color.clear
                                    .frame(width: dayCellSize, height: dayCellSize * 1.65)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.93))
        }
    }
}

#Preview {
    CalendarYearOverviewView(year: 2026, onDayZoom: { _ in })
        .environment(WorkCalendarStore())
        .environment(ShiftStore())
        .environment(ShiftTypeStore())
}