//
//  CalendarScreenToolbar.swift
//  Tempo
//

import SwiftUI

struct CalendarScreenToolbar: View {
    let calendarName: String
    let headerColor: Color
    let onPickCalendar: () -> Void
    let onShare: () -> Void
    let onSettings: () -> Void

    private var usesLightForeground: Bool {
        ColorContrast.prefersLightForeground(for: headerColor)
    }

    private var foreground: Color {
        usesLightForeground ? .white : .black
    }

    private var pillBackground: Color {
        usesLightForeground ? .white.opacity(0.2) : .black.opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPickCalendar) {
                HStack(spacing: 6) {
                    Text(calendarName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .opacity(0.85)
                }
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(pillBackground)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Elegir calendario")

            Spacer(minLength: 0)

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(foreground)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Compartir")

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(foreground)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ajustes")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            headerColor
                .ignoresSafeArea(edges: .top)
        }
    }
}

#Preview {
    CalendarScreenToolbar(
        calendarName: "Principal",
        headerColor: Color(hex: "#C6E7FF") ?? .blue.opacity(0.3),
        onPickCalendar: {},
        onShare: {},
        onSettings: {}
    )
}