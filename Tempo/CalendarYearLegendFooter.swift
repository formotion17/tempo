//
//  CalendarYearLegendFooter.swift
//  Tempo
//

import SwiftUI

struct CalendarYearLegendFooter: View {
    @Environment(WorkCalendarStore.self) private var calendarStore
    @Environment(ShiftTypeStore.self) private var shiftTypeStore

    private var host: WorkCalendar {
        calendarStore.selectedCalendar
    }

    private var mainShiftTypes: [ShiftTypeDefinition] {
        shiftTypeStore.shiftTypes(linkedTo: host.shiftTypeIDs)
    }

    private var overlayBlocks: [(overlay: CalendarOverlay, source: WorkCalendar)] {
        host.overlays.compactMap { overlay in
            guard let source = calendarStore.calendar(id: overlay.sourceCalendarID) else { return nil }
            return (overlay, source)
        }
    }

    var body: some View {
        legendContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(alignment: .top) { Divider() }
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legendContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legendBlock(title: host.name) {
                if mainShiftTypes.isEmpty {
                    Text("Sin turnos en la paleta de este calendario.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LegendChipFlowLayout(spacing: 6) {
                        ForEach(mainShiftTypes) { shift in
                            shiftCapsule(shift.name, color: shift.color)
                        }
                    }
                }
            }

            if !overlayBlocks.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(overlayBlocks, id: \.overlay.id) { block in
                        overlayLegendCard(overlay: block.overlay, source: block.source)
                    }
                }
            }
        }
    }

    private func overlayLegendCard(overlay: CalendarOverlay, source: WorkCalendar) -> some View {
        let shifts = overlay.includedShiftTypeIDs.compactMap { shiftTypeStore.shiftType(id: $0) }
        return VStack(alignment: .leading, spacing: 8) {
            Text(source.listDisplayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            if shifts.isEmpty {
                Text("Sin turnos visibles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shifts) { shift in
                    let appearance = overlay.bubbleAppearance(for: shift.id, shiftTypeStore: shiftTypeStore)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appearance.color)
                            .frame(width: 9, height: 9)
                        Text(shift.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
    }

    private func shiftCapsule(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(color)
            }
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Dispone cápsulas con el ancho del texto (una línea) y salta de fila si no caben.
private struct LegendChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    CalendarYearLegendFooter()
        .environment(WorkCalendarStore())
        .environment(ShiftTypeStore())
}