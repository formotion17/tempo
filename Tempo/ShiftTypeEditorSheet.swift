//
//  ShiftTypeEditorSheet.swift
//  Tempo
//

import SwiftUI

struct ShiftTypeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (ShiftTypeDefinition) -> Void

    @State private var name: String
    @State private var initials: String
    @State private var selectedColorHex: String
    @State private var usesSchedule: Bool
    @State private var startTime: Date
    @State private var endTime: Date

    private let existingID: UUID?

    init(shiftType: ShiftTypeDefinition? = nil, onSave: @escaping (ShiftTypeDefinition) -> Void) {
        self.title = shiftType == nil ? "Nuevo turno" : "Editar turno"
        self.onSave = onSave
        self.existingID = shiftType?.id
        _name = State(initialValue: shiftType?.name ?? "")
        _initials = State(initialValue: shiftType?.initials ?? "")
        _selectedColorHex = State(initialValue: shiftType?.colorHex ?? ShiftTypeColorOption.morningYellow.rawValue)

        if let shiftType, let parsed = ShiftScheduleFormatting.parsedTimes(from: shiftType.schedule) {
            _usesSchedule = State(initialValue: true)
            _startTime = State(initialValue: parsed.start)
            _endTime = State(initialValue: parsed.end)
        } else {
            _usesSchedule = State(initialValue: false)
            _startTime = State(initialValue: ShiftScheduleFormatting.defaultStart())
            _endTime = State(initialValue: ShiftScheduleFormatting.defaultEnd())
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var scheduleToSave: String {
        guard usesSchedule else { return "" }
        return ShiftScheduleFormatting.string(from: startTime, to: endTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Mañana", text: $name)
                }

                Section("Iniciales") {
                    TextField("Ej. M", text: $initials)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Text("Se muestran en el calendario.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ShiftTypeColorOption.allCases) { option in
                            colorSwatch(option)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("Definir horario", isOn: $usesSchedule)
                }

                if usesSchedule {
                    Section("Horario") {
                        DatePicker("Inicio", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("Fin", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TempoSheetToolbar.dismissButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    TempoSheetToolbar.saveButton(disabled: !canSave) {
                        let definition = ShiftTypeDefinition(
                            id: existingID ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            initials: initials.trimmingCharacters(in: .whitespacesAndNewlines),
                            colorHex: selectedColorHex,
                            schedule: scheduleToSave
                        )
                        onSave(definition)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
        .accessibilityLabel("Color \(option.rawValue)")
    }
}

#Preview {
    ShiftTypeEditorSheet { _ in }
}