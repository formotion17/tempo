//
//  CalendarsView.swift
//  Tempo
//

import SwiftUI

struct CalendarsView: View {
    @Environment(WorkCalendarStore.self) private var calendarStore

    @Binding var selectedAction: CalendarDayAction
    @Binding var surfaceMode: CalendarSurfaceMode
    var onDayZoom: (Date) -> Void

    private var calendar: Calendar { Calendar.current }

    @State private var displayedMonth = Date()
    @State private var displayedYear: Int = MonthCalendarLogic.currentYear()

    private static let monthHeaderHeight: CGFloat = 32
    private static let titleClusterWidth: CGFloat = 196
    private static let weekdayHeaderHeight: CGFloat = 18
    private static let sectionSpacing: CGFloat = 4
    private static let gridRowSpacing: CGFloat = 6
    private static let fixedWeekRowCount = MonthCalendarLogic.fixedWeekRowCount

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var isDisplayingCurrentYear: Bool {
        displayedYear == MonthCalendarLogic.currentYear(calendar: calendar)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_ES")))
    }

    private var yearTitle: String {
        String(displayedYear)
    }

    private var gridDays: [MonthGridDay] {
        MonthCalendarLogic.monthGridDays(for: displayedMonth, calendar: calendar)
    }

    var body: some View {
        VStack(spacing: Self.sectionSpacing) {
            monthHeader
                .frame(height: Self.monthHeaderHeight)

            if surfaceMode == .month {
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
            } else {
                CalendarYearOverviewView(year: displayedYear, onDayZoom: onDayZoom)
            }
        }
        .padding(.horizontal, surfaceMode == .year ? 4 : 10)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surfaceMode == .year ? Color.white : Color.clear)
        .onAppear {
            syncYearFromMonth()
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 4) {
            if surfaceMode == .month {
                monthStepButton(offset: -1, label: "Mes anterior", systemImage: "chevron.left")
            } else {
                yearStepButton(offset: -1)
            }

            HStack(spacing: 8) {
                Text(surfaceMode == .month ? monthTitle.capitalized : yearTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
                    .animation(.snappy, value: monthTitle)

                if surfaceMode == .month, !isDisplayingCurrentMonth {
                    Button("HOY") {
                        goToToday()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Ir al mes actual")
                } else if surfaceMode == .year, !isDisplayingCurrentYear {
                    Button("HOY") {
                        goToCurrentYear()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Ir al año actual")
                } else if surfaceMode == .month {
                    Color.clear
                        .frame(width: 44, height: 1)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: Self.titleClusterWidth)

            if surfaceMode == .month {
                monthStepButton(offset: 1, label: "Mes siguiente", systemImage: "chevron.right")
            } else {
                yearStepButton(offset: 1)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.snappy) {
                    if surfaceMode == .month {
                        syncYearFromMonth()
                        surfaceMode = .year
                    } else {
                        surfaceMode = .month
                    }
                }
            } label: {
                Image(systemName: surfaceMode == .month ? "rectangle.grid.2x2" : "calendar")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(surfaceMode == .month ? "Ver año" : "Ver mes")
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
                    workCalendarID: calendarStore.selectedCalendarID,
                    assignmentsLocked: calendarStore.selectedCalendar.isImported,
                    selectedAction: selectedAction,
                    onZoomRequest: gridDay.isInDisplayedMonth ? { onDayZoom(gridDay.date) } : nil
                )
            }
        }
        .animation(.snappy, value: displayedMonth)
    }

    private func monthStepButton(offset: Int, label: String, systemImage: String) -> some View {
        Button {
            changeMonth(by: offset)
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func yearStepButton(offset: Int) -> some View {
        Button {
            changeYear(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(offset < 0 ? "Año anterior" : "Año siguiente")
    }

    private func changeMonth(by offset: Int) {
        withAnimation(.snappy) {
            displayedMonth = MonthCalendarLogic.shiftedMonth(from: displayedMonth, by: offset, calendar: calendar)
            displayedYear = calendar.component(.year, from: displayedMonth)
        }
    }

    private func changeYear(by offset: Int) {
        withAnimation(.snappy) {
            displayedYear += offset
        }
    }

    private func goToToday() {
        withAnimation(.snappy) {
            displayedMonth = Date()
            displayedYear = MonthCalendarLogic.currentYear(calendar: calendar)
        }
    }

    private func goToCurrentYear() {
        withAnimation(.snappy) {
            displayedYear = MonthCalendarLogic.currentYear(calendar: calendar)
        }
    }

    private func syncYearFromMonth() {
        displayedYear = calendar.component(.year, from: displayedMonth)
    }
}

#Preview {
    @Previewable @State var action: CalendarDayAction = .none
    @Previewable @State var mode: CalendarSurfaceMode = .year
    CalendarsView(selectedAction: $action, surfaceMode: $mode, onDayZoom: { _ in })
        .environment(ShiftStore())
        .environment(ShiftTypeStore())
        .environment(WorkCalendarStore())
}