//
//  ContentView.swift
//  Tempo
//

import SwiftUI

private enum RootScreen {
    case calendar
    case settings
    case shiftTypes
    case calendars
}

struct ContentView: View {
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore

    @State private var rootScreen: RootScreen = .calendar
    @State private var showsCalendarPicker = false
    @State private var showsOptionsMenu = false
    @State private var selectedDayAction: CalendarDayAction = .none
    @State private var showsPaletteShiftEditor = false
    @State private var paletteEditingShiftType: ShiftTypeDefinition?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            screenContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))

            if showsOptionsMenu, rootScreen == .calendar {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy) {
                            showsOptionsMenu = false
                        }
                    }

                SettingsOptionsMenu(
                    onSelectCalendars: {
                        withAnimation(.snappy) {
                            showsOptionsMenu = false
                            rootScreen = .calendars
                        }
                    },
                    onSelectShiftTypes: {
                        withAnimation(.snappy) {
                            showsOptionsMenu = false
                            rootScreen = .shiftTypes
                        }
                    },
                    onSelectSettings: {
                        withAnimation(.snappy) {
                            showsOptionsMenu = false
                            rootScreen = .settings
                        }
                    }
                )
                .padding(.top, 56)
                .padding(.trailing, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: showsOptionsMenu)
        .sheet(isPresented: $showsCalendarPicker) {
            CalendarPickerSheet()
        }
        .sheet(isPresented: $showsPaletteShiftEditor) {
            ShiftTypeEditorSheet(shiftType: paletteEditingShiftType) { definition in
                shiftTypeStore.updateShiftType(definition)
            }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch rootScreen {
        case .calendar:
            calendarScreen
        case .settings:
            SettingsView {
                withAnimation(.snappy) { rootScreen = .calendar }
            }
        case .shiftTypes:
            ShiftTypesView {
                withAnimation(.snappy) { rootScreen = .calendar }
            }
        case .calendars:
            CalendarsManagementView {
                withAnimation(.snappy) { rootScreen = .calendar }
            }
        }
    }

    private var calendarScreen: some View {
        VStack(spacing: 0) {
            CalendarScreenToolbar(
                calendarName: calendarStore.selectedCalendar.name,
                headerColor: calendarStore.selectedCalendar.color,
                onPickCalendar: { showsCalendarPicker = true },
                onShare: { /* próximamente */ },
                onSettings: {
                    withAnimation(.snappy) {
                        showsOptionsMenu.toggle()
                    }
                }
            )

            CalendarsView(selectedAction: $selectedDayAction)

            CalendarShiftPaletteView(selectedAction: $selectedDayAction) { shiftType in
                paletteEditingShiftType = shiftType
                showsPaletteShiftEditor = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(ShiftStore())
        .environment(WorkCalendarStore())
        .environment(ShiftTypeStore())
}