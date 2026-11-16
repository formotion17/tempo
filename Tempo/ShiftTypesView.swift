//
//  ShiftTypesView.swift
//  Tempo
//

import SwiftUI

struct ShiftTypesView: View {
    @Environment(ShiftTypeStore.self) private var shiftTypeStore
    @Environment(ShiftStore.self) private var shiftStore

    let onBack: () -> Void

    @State private var showsEditor = false
    @State private var editingShiftType: ShiftTypeDefinition?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(shiftTypeStore.shiftTypes) { shiftType in
                        shiftTypeCard(shiftType)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showsEditor) {
            ShiftTypeEditorSheet(shiftType: editingShiftType) { definition in
                if editingShiftType != nil {
                    shiftTypeStore.updateShiftType(definition)
                } else {
                    shiftTypeStore.addShiftType(definition)
                }
            }
        }
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
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Turnos")
                .font(.headline.weight(.semibold))

            Spacer()

            Button {
                editingShiftType = nil
                showsEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir turno")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func shiftTypeCard(_ shiftType: ShiftTypeDefinition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(shiftType.displayInitials)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.black.opacity(0.08))
                            }
                        Text(shiftType.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.black)
                    }
                    if shiftType.hasSchedule {
                        Text(shiftType.schedule)
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.65))
                    }
                }
                Spacer(minLength: 12)

                HStack(spacing: 4) {
                    Button {
                        editingShiftType = shiftType
                        showsEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body.weight(.medium))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.black.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Editar")

                    Button(role: .destructive) {
                        shiftStore.removeShifts(shiftTypeID: shiftType.id)
                        shiftTypeStore.deleteShiftType(id: shiftType.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.body.weight(.medium))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eliminar")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(shiftType.color)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
        }
    }
}

#Preview {
    ShiftTypesView(onBack: {})
        .environment(ShiftTypeStore())
}