//
//  SettingsView.swift
//  Tempo
//

import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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

            VStack(spacing: 12) {
                Image(systemName: "gearshape")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Ajustes")
                    .font(.title2.weight(.semibold))
                Text("Próximamente podrás configurar la app aquí.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    SettingsView(onBack: {})
}