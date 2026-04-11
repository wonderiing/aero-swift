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
    static let maxStudyListWidth: CGFloat = 1180
    static let sidebarWidth: CGFloat = 220

    static func studyGridItems(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let large = aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass)
        if !large { return [GridItem(.flexible(), spacing: 14)] }
        return [GridItem(.adaptive(minimum: 296, maximum: 420), spacing: 18, alignment: .top)]
    }
}

enum AeroType {
    static func studyGreeting(largeCanvas: Bool) -> Font {
        largeCanvas
            ? .system(.title, design: .rounded).weight(.bold)
            : .system(.title2, design: .rounded).weight(.bold)
    }
    static func studyCardTitle(largeCanvas: Bool) -> Font {
        largeCanvas
            ? .system(.title3, design: .default).weight(.semibold)
            : .system(.headline, design: .default).weight(.semibold)
    }
    static func studyCardBody(largeCanvas: Bool) -> Font {
        largeCanvas ? .body : .subheadline
    }
    static func sectionOverline() -> Font { .caption.weight(.semibold) }
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

    // MARK: - Atheneum / Stitch design system

    /// Indigo-navy principal — botones, activos, énfasis.
    static let aeroNavy = Color(red: 0.18, green: 0.22, blue: 0.56)

    /// Sidebar background — muy oscuro.
    static let aeroNavyDeep = Color(red: 0.07, green: 0.09, blue: 0.26)

    /// Accent claro — highlights, tags, badges.
    static let aeroLavender = Color(red: 0.48, green: 0.56, blue: 0.95)

    /// Verde progreso / acierto.
    static let aeroMint = Color(red: 0.27, green: 0.76, blue: 0.49)

    static var aeroCardFill: Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}
