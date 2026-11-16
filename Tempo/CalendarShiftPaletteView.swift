//
//  CalendarShiftPaletteView.swift
//  Tempo
//

import SwiftUI

struct CalendarShiftPaletteView: View {
    @Environment(ShiftTypeStore.self) private var shiftTypeStore

    @Binding var selectedAction: CalendarDayAction
    var onEditShiftType: (ShiftTypeDefinition) -> Void

    private let toolHeight: CGFloat = 80
    private let shiftCardWidth: CGFloat = 56
    private let gridRowSpacing: CGFloat = 4

    private var shiftCardHeight: CGFloat {
        (toolHeight - gridRowSpacing) / 2
    }

    private var shiftGridRows: [GridItem] {
        [
            GridItem(.fixed(shiftCardHeight), spacing: gridRowSpacing),
            GridItem(.fixed(shiftCardHeight), spacing: gridRowSpacing),
        ]
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 12) {
                clearDayCard

                LazyHGrid(rows: shiftGridRows, alignment: .center, spacing: 8) {
                    ForEach(shiftTypeStore.shiftTypes) { shiftType in
                        shiftTypeCard(shiftType)
                    }
                }
                .frame(height: toolHeight)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        }
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var clearDayCard: some View {
        let isSelected = selectedAction == .clearDay
        return Button {
            withAnimation(.snappy) {
                selectedAction = isSelected ? .none : .clearDay
            }
        } label: {
            Image(systemName: "eraser.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: toolHeight, height: toolHeight)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Limpiar día")
    }

    private func shiftTypeCard(_ shiftType: ShiftTypeDefinition) -> some View {
        let isSelected = selectedAction == .applyShift(shiftType.id)
        return Button {
            withAnimation(.snappy) {
                selectedAction = isSelected ? .none : .applyShift(shiftType.id)
            }
        } label: {
            Text(shiftType.displayInitials)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .frame(width: shiftCardWidth, height: shiftCardHeight)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(shiftType.color)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 0.5)
                }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                onEditShiftType(shiftType)
            }
        )
        .accessibilityLabel(shiftType.name)
    }
}

#Preview {
    @Previewable @State var action: CalendarDayAction = .none
    CalendarShiftPaletteView(selectedAction: $action, onEditShiftType: { _ in })
        .environment(ShiftTypeStore())
}