import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

enum AeroAdaptiveLayout {
    static let maxCompactContentWidth: CGFloat = 560
    static let maxRegularContentWidth: CGFloat = 920
}

func aeroIsLargeCanvas(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
    #if os(macOS)
    return true
    #else
    return UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    #endif
}

extension Color {
    static var aeroGroupedBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var aeroSecondaryBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
