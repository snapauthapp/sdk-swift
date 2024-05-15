//
//  Base64URL.swift
//  PassKeyExample
//
//  Created by Eric Stern on 3/13/24.
//

import Foundation

struct Base64URL: Codable {
    private var base64URLString: String
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
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
        // does this need to be padded?
        if let data = Data(base64Encoded: rawBase64) {
            return data
        }
        return nil
     }
     
//     init(base64String: String) {
//         self.base64String = base64String
//     }
}
extension Base64URL: CustomStringConvertible {
     var description: String {
        return base64URLString
    }
}
