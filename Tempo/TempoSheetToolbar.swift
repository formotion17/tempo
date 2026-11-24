//
//  TempoSheetToolbar.swift
//  Tempo
//

import SwiftUI

enum TempoSheetToolbar {
    static func dismissButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel("Cerrar")
    }

    static func saveButton(disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.body.weight(.semibold))
        }
        .disabled(disabled)
        .accessibilityLabel("Guardar")
    }
}