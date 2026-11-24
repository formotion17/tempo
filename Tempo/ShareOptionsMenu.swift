//
//  ShareOptionsMenu.swift
//  Tempo
//

import SwiftUI

struct ShareOptionsMenu: View {
    let onExportCalendar: () -> Void
    let onExportDatabase: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            menuBubble(title: "Exportar calendario", icon: "calendar", action: onExportCalendar)
            menuBubble(title: "Exportar base de datos", icon: "square.and.arrow.up", action: onExportDatabase)
        }
    }

    private func menuBubble(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            }
            .overlay {
                Capsule()
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShareOptionsMenu(onExportCalendar: {}, onExportDatabase: {})
        .padding()
}