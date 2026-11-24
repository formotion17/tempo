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
    @Environment(ShiftStore.self) private var shiftStore

    @State private var rootScreen: RootScreen = .calendar
    @State private var showsCalendarPicker = false
    @State private var showsOptionsMenu = false
    @State private var showsShareMenu = false
    @State private var selectedDayAction: CalendarDayAction = .none
    @State private var calendarSurfaceMode: CalendarSurfaceMode = .month
    @State private var zoomedDay: ZoomedDayPresentation?
    @State private var showsPaletteShiftEditor = false
    @State private var paletteEditingShiftType: ShiftTypeDefinition?
    @State private var shareFile: ShareableExportFile?
    @State private var exportErrorMessage: String?
    @State private var databaseExportReview: TempoDatabaseExportFile?
    @State private var calendarExportRequest: CalendarExportSheetItem?

    @AppStorage(AppPreferenceKeys.showsYearCalendarLegend)
    private var showsYearCalendarLegend = true

    @State private var summaryYear = MonthCalendarLogic.currentYear()
    @State private var showsYearSummary = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            screenContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))

            if rootScreen == .calendar {
                if showsShareMenu {
                    dismissMenusOverlay {
                        withAnimation(.snappy) { showsShareMenu = false }
                    }

                    ShareOptionsMenu(
                        onExportCalendar: prepareExportSelectedCalendar,
                        onExportDatabase: prepareExportDatabase
                    )
                        .padding(.top, 56)
                        .padding(.trailing, 56)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if showsOptionsMenu {
                    dismissMenusOverlay {
                        withAnimation(.snappy) { showsOptionsMenu = false }
                    }

                    SettingsOptionsMenu(
                        onSelectCalendars: {
                            withAnimation(.snappy) {
                                closeMenus()
                                rootScreen = .calendars
                            }
                        },
                        onSelectShiftTypes: {
                            withAnimation(.snappy) {
                                closeMenus()
                                rootScreen = .shiftTypes
                            }
                        },
                        onSelectSettings: {
                            withAnimation(.snappy) {
                                closeMenus()
                                rootScreen = .settings
                            }
                        }
                    )
                    .padding(.top, 56)
                    .padding(.trailing, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: showsOptionsMenu)
        .animation(.snappy(duration: 0.25), value: showsShareMenu)
        .sheet(isPresented: $showsCalendarPicker) {
            CalendarPickerSheet()
        }
        .sheet(isPresented: $showsPaletteShiftEditor) {
            ShiftTypeEditorSheet(shiftType: paletteEditingShiftType) { definition in
                shiftTypeStore.updateShiftType(definition)
            }
        }
        .sheet(item: $shareFile) { file in
            ActivityShareSheet(items: [file.url])
        }
        .sheet(isPresented: $showsYearSummary) {
            CalendarYearSummarySheet(year: summaryYear)
        }
        .sheet(item: $databaseExportReview) { export in
            TempoExportReviewView(export: export) {
                confirmExport(.database(export))
            }
        }
        .sheet(item: $calendarExportRequest) { request in
            TempoCalendarExportReviewView(calendarID: request.calendarID) { export in
                confirmExport(.calendar(export))
            }
        }
        .alert("No se pudo exportar", isPresented: exportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Error desconocido")
        }
        .onAppear {
            calendarStore.linkAllShiftTypesIfEmpty(shiftTypeStore.shiftTypes.map(\.id))
        }
    }

    private var exportErrorPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    private func dismissMenusOverlay(onTap: @escaping () -> Void) -> some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .onTapGesture(perform: onTap)
    }

    private func closeMenus() {
        showsOptionsMenu = false
        showsShareMenu = false
    }

    private func prepareExportSelectedCalendar() {
        withAnimation(.snappy) {
            showsShareMenu = false
        }

        calendarExportRequest = CalendarExportSheetItem(calendarID: calendarStore.selectedCalendarID)
    }

    private func prepareExportDatabase() {
        withAnimation(.snappy) {
            showsShareMenu = false
        }

        let export = CalendarExportService.buildDatabaseExport(
            shiftTypes: shiftTypeStore.shiftTypes,
            calendars: calendarStore.calendars,
            selectedCalendarID: calendarStore.selectedCalendarID,
            shiftStore: shiftStore
        )
        databaseExportReview = export
    }

    private func confirmExport(_ payload: TempoExportPayload) {
        do {
            let url = try CalendarExportService.writeTemporaryFile(for: payload)
            shareFile = ShareableExportFile(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
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
                onSummary: {
                    withAnimation(.snappy) {
                        closeMenus()
                        showsYearSummary = true
                    }
                },
                onShare: {
                    withAnimation(.snappy) {
                        showsOptionsMenu = false
                        showsShareMenu.toggle()
                    }
                },
                onSettings: {
                    withAnimation(.snappy) {
                        showsShareMenu = false
                        showsOptionsMenu.toggle()
                    }
                }
            )

            CalendarsView(
                selectedAction: $selectedDayAction,
                surfaceMode: $calendarSurfaceMode,
                summaryYear: $summaryYear,
                onDayZoom: { date in
                    zoomedDay = ZoomedDayPresentation(date: date)
                }
            )
            .layoutPriority(1)

            calendarBottomBar
        }
        .onChange(of: calendarStore.selectedCalendarID) { _, _ in
            selectedDayAction = .none
        }
        .onChange(of: calendarSurfaceMode) { _, newMode in
            if newMode == .year {
                selectedDayAction = .none
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(calendarSurfaceMode == .year ? Color.white : Color(.systemGroupedBackground))
        .sheet(item: $zoomedDay) { item in
            CalendarYearDayZoomSheet(date: item.date)
        }
    }

    @ViewBuilder
    private var calendarBottomBar: some View {
        switch calendarSurfaceMode {
        case .year:
            if showsYearCalendarLegend {
                CalendarYearLegendFooter()
                    .layoutPriority(0)
            }
        case .month:
            if calendarStore.selectedCalendar.isImported {
                importedCalendarFooter
            } else {
                CalendarShiftPaletteView(selectedAction: $selectedDayAction) { shiftType in
                    paletteEditingShiftType = shiftType
                    showsPaletteShiftEditor = true
                }
            }
        }
    }

    private var importedCalendarFooter: some View {
        Text("Calendario importado: solo lectura en los días. Edita nombre y abreviaturas desde Calendarios.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
            }
    }
}

private struct CalendarExportSheetItem: Identifiable {
    let calendarID: UUID
    var id: UUID { calendarID }
}

private struct ShareableExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    ContentView()
        .environment(ShiftStore())
        .environment(WorkCalendarStore())
        .environment(ShiftTypeStore())
}