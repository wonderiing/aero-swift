import Foundation

/// Wrapper que permite codificar un `Encodable` existencial (`any Encodable`)
/// sin necesitar un tipo genérico concreto en el sitio de llamada.
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
