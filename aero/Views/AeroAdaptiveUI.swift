import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

enum AeroAdaptiveLayout {
    static let maxCompactContentWidth: CGFloat = 560
    /// Ancho máximo del contenido en iPhone landscape / iPad.
    static let maxRegularContentWidth: CGFloat = 920
    /// Lista de estudios en iPad ancho: permite 3 columnas cómodas.
    static let maxStudyListWidth: CGFloat = 1180

    /// Rejilla de tarjetas: en iPhone 1 columna; en iPad columnas adaptativas (2–3 según ancho).
    static func studyGridItems(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let large = aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass)
        if !large {
            return [GridItem(.flexible(), spacing: 14)]
        }
        return [GridItem(.adaptive(minimum: 296, maximum: 420), spacing: 18, alignment: .top)]
    }
}

// MARK: - Tipografía adaptativa (Dynamic Type + iPad)

enum AeroType {
    /// Saludo / título destacado en lista de estudios.
    static func studyGreeting(largeCanvas: Bool) -> Font {
        largeCanvas
            ? .system(.title, design: .rounded).weight(.bold)
            : .system(.title2, design: .rounded).weight(.bold)
    }

    /// Título de cada tarjeta de estudio.
    static func studyCardTitle(largeCanvas: Bool) -> Font {
        largeCanvas
            ? .system(.title3, design: .default).weight(.semibold)
            : .system(.headline, design: .default).weight(.semibold)
    }

    /// Cuerpo secundario en tarjetas (descripción).
    static func studyCardBody(largeCanvas: Bool) -> Font {
        largeCanvas ? .body : .subheadline
    }

    /// Rótulos de sección (mayúsculas) — respeta Dynamic Type.
    static func sectionOverline() -> Font {
        .caption.weight(.semibold)
    }
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

    // MARK: - Atheneum-style brand (navy + lavanda)

    /// Azul marino principal (botones, títulos de énfasis, pestaña activa).
    static let aeroNavy = Color(red: 0.10, green: 0.17, blue: 0.38)

    /// Variante más oscura para cabeceras y gradientes suaves.
    static let aeroNavyDeep = Color(red: 0.05, green: 0.09, blue: 0.20)

    /// Acento suave tipo mockup (highlights, chips).
    static let aeroLavender = Color(red: 0.58, green: 0.54, blue: 0.94)

    /// Barra de progreso / acierto (verde menta del diseño).
    static let aeroMint = Color(red: 0.36, green: 0.78, blue: 0.62)

    /// Relleno de tarjeta en modo claro (blanco puro sobre gris de fondo).
    static var aeroCardFill: Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}
