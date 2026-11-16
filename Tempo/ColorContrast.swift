//
//  ColorContrast.swift
//  Tempo
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ColorContrast {
    static func prefersLightForeground(for color: Color) -> Bool {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var white: CGFloat = 0
        uiColor.getWhite(&white, alpha: nil)
        return white < 0.55
        #else
        return false
        #endif
    }
}