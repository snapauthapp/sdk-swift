import Foundation

/// Converts in and out of Base64URL formats
struct Base64URL: Codable {
    let base64URLString: String

    init(_ base64URLString: String) {
        self.base64URLString = base64URLString
    }

    /// Allows for direct decoding of Base64URL values from e.g. JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        base64URLString = try container.decode(String.self)
    }

    /// Reads in Data representing a base64 (not base64url) string
    init(from data: Data) {
        base64URLString = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // FIXME: this should be explicitly rtrim
    }

    /// Allows direct encoding into a Base64URL string to e.g. JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(base64URLString)
    }

    func toData() -> Data? {
        var rawBase64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = rawBase64.count % 4
        if (remainder > 0) {
            rawBase64.append(String(repeating: "=", count: 4 - remainder))
        }
        if let data = Data(base64Encoded: rawBase64) {
            return data
        }
        return nil
    }
}

extension Base64URL: CustomStringConvertible {
    var description: String {
        return base64URLString
    }
}
