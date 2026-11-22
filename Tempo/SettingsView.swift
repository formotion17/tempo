//
//  SettingsView.swift
//  Tempo
//

import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void

    @AppStorage(AppPreferenceKeys.showsYearCalendarLegend)
    private var showsYearCalendarLegend = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                Section {
                    Toggle("Mostrar leyenda de turnos", isOn: $showsYearCalendarLegend)
                } header: {
                    Text("Vista anual")
                } footer: {
                    Text(
                        "Recuadro inferior con los turnos del calendario principal y de los calendarios superpuestos."
                    )
                }
            }
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Calendario")
                        .font(.body.weight(.medium))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volver al calendario")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

#Preview {
    SettingsView(onBack: {})
}