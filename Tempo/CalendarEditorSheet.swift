//
//  CalendarEditorSheet.swift
//  Tempo
//

import SwiftUI

struct CalendarEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (WorkCalendar) -> Void

    @State private var name: String
    @State private var selectedColorHex: String

    private let existingID: UUID?

    init(calendar: WorkCalendar? = nil, onSave: @escaping (WorkCalendar) -> Void) {
        self.title = calendar == nil ? "Nuevo calendario" : "Editar calendario"
        self.onSave = onSave
        self.existingID = calendar?.id
        _name = State(initialValue: calendar?.name ?? "")
        _selectedColorHex = State(initialValue: calendar?.colorHex ?? ShiftTypeColorOption.sky.rawValue)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Equipo A", text: $name)
                }

                Section("Color de cabecera") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ShiftTypeColorOption.allCases) { option in
                            colorSwatch(option)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let calendar = WorkCalendar(
                            id: existingID ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            colorHex: selectedColorHex
                        )
                        onSave(calendar)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func colorSwatch(_ option: ShiftTypeColorOption) -> some View {
        let isSelected = selectedColorHex == option.rawValue
        return Button {
            selectedColorHex = option.rawValue
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 40, height: 40)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 2)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarEditorSheet { _ in }
}