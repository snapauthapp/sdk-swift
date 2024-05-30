import Foundation

/// Converts in and out of Base64URL formats
struct Base64URL {
    enum Base64UrlError: Error {
        case invalidData
    }

    /// The raw underlying information
    let data: Data

    /// The encoded string representation
    var string: String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // FIXME: this should be explicitly rtrim
    }

    init(from data: Data) {
        self.data = data
    }

    /// Initialize from a base64URL-formatted string. Throws if the string is
    /// not valid. This is intended to ease testing and decoding, and not
    /// general use.
    init(_ base64URLString: String) throws {
        var rawBase64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = rawBase64.count % 4
        if (remainder > 0) {
            rawBase64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: rawBase64) else {
            throw Base64UrlError.invalidData
        }
        self.data = data
    }

}

/// Implements the Codable protocol by using the string representation
extension Base64URL: Codable {

    /// Allows for direct decoding of Base64URL values from e.g. JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let base64URLString = try container.decode(String.self)
        try self.init(base64URLString)
    }

    /// Allows direct encoding into a Base64URL string to e.g. JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension Base64URL: CustomStringConvertible {
    var description: String {
        return string
    }
}
