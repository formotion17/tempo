//
//  CalendarAddOptionsMenu.swift
//  Tempo
//

import SwiftUI

struct CalendarAddOptionsMenu: View {
    let onNewCalendar: () -> Void
    let onImportCalendar: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            menuBubble(title: "Nuevo calendario", icon: "plus", action: onNewCalendar)
            menuBubble(title: "Importar calendario", icon: "square.and.arrow.down", action: onImportCalendar)
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
    CalendarAddOptionsMenu(onNewCalendar: {}, onImportCalendar: {})
        .padding()
}