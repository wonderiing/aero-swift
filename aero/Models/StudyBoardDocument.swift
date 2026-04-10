import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Canvas document (persisted as JSON on SDStudyBoard)

struct BoardDocument: Codable, Equatable {
    var elements: [BoardElement]

    static let empty = BoardDocument(elements: [])

    static func decode(from json: String) -> BoardDocument? {
        guard !json.isEmpty,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BoardDocument.self, from: data)
    }

    func encodedJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct BoardElement: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: Kind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var colorHex: String
    var strokeWidth: Double
    /// Contenido para `.text`
    var text: String
    /// Trazo libre; coordenadas en espacio del lienzo
    var points: [CanvasPoint]?

    enum Kind: String, Codable {
        case text
        case rectangle
        case ellipse
        case arrow
        case pen
    }
}

struct CanvasPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var n: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&n), s.count == 6 || s.count == 8 else {
            self = .primary
            return
        }
        let a, r, g, b: UInt64
        if s.count == 8 {
            a = (n >> 24) & 0xFF
            r = (n >> 16) & 0xFF
            g = (n >> 8) & 0xFF
            b = n & 0xFF
        } else {
            a = 255
            r = (n >> 16) & 0xFF
            g = (n >> 8) & 0xFF
            b = n & 0xFF
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHexRGB() -> String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #elseif canImport(AppKit)
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        return String(
            format: "%02X%02X%02X",
            Int(ns.redComponent * 255),
            Int(ns.greenComponent * 255),
            Int(ns.blueComponent * 255)
        )
        #else
        return "000000"
        #endif
    }
}
