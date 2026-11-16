//
//  TempoApp.swift
//  Tempo
//
//  Created by Iban Trabajo on 16/11/26.
//

import SwiftUI

@main
struct TempoApp: App {
    @State private var shiftStore = ShiftStore()
    @State private var workCalendarStore = WorkCalendarStore()
    @State private var shiftTypeStore = ShiftTypeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(shiftStore)
                .environment(workCalendarStore)
                .environment(shiftTypeStore)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .background || newPhase == .inactive else { return }
                    shiftStore.persistAssignments()
                    shiftTypeStore.persistShiftTypes()
                    workCalendarStore.persistCalendars()
                }
        }
    }
}