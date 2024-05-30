@testable import SnapAuth
import XCTest

final class Base64URLTests: XCTestCase {
    let validBase64UrlTestCases: [(String, Data)] = [
        ("", Data()), // empty string
        ("Zg", "f".data(using: .utf8)!), // "f"
        ("Zm8", "fo".data(using: .utf8)!), // "fo"
        ("Zm9v", "foo".data(using: .utf8)!), // "foo"
        ("Zm9vYg", "foob".data(using: .utf8)!), // "foob"
        ("Zm9vYmE", "fooba".data(using: .utf8)!), // "fooba"
        ("Zm9vYmFy", "foobar".data(using: .utf8)!), // "foobar"
        ("SGVsbG8td29ybGQ", "Hello-world".data(using: .utf8)!), // "Hello-world" (no padding, - instead of +)
        ("SGVsbG8_d29ybGQ", "Hello?world".data(using: .utf8)!), // "Hello?world" (no padding, _ instead of /)
        ("SGVsbG8", "Hello".data(using: .utf8)!), // "Hello"
        ("SGVsbG8gd29ybGQ", "Hello world".data(using: .utf8)!), // "Hello world"
        ("U29tZSByYW5kb20gdGV4dA", "Some random text".data(using: .utf8)!), // "Some random text"
        ("Zm9vYmFyCg", "foobar\n".data(using: .utf8)!), // "foobar\n" (no padding)
//            ("Zm9vYmFyCg==", "foobar\n".data(using: .utf8)!), // "foobar\n" (padding)
        ("MTIzNDU2Nzg5MA", "1234567890".data(using: .utf8)!), // "1234567890"
        ("L3Vzci9iaW4vZW52Cg", "/usr/bin/env\n".data(using: .utf8)!), // "/usr/bin/env\n"
        ("U3dpZnQgbGlrZSBzb2Z0d2FyZQo", "Swift like software\n".data(using: .utf8)!), // "Swift like software\n"
        ("U29tZSB0ZXh0IHdpdGggb25lIHNwYWNl", "Some text with one space".data(using: .utf8)!), // "Some text with one space"
        ("U29tZSB0ZXh0IHdpdGggdHdvIHNwYWNl", "Some text with two space".data(using: .utf8)!), // "Some text with two space"
        ("U29tZSB0ZXh0IHdpdGggdGhyZWUgc3BhY2Vz", "Some text with three spaces".data(using: .utf8)!), // "Some text with three spaces"
        ("AAEC", Data([0x00, 0x01, 0x02])), // binary data 00 01 02
        ("AQIDBAUGBwgJCgsMDQ4P", Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F])) // binary data 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
    ]

    let invalidBase64UrlStrings: [String] = [
//        "===", // only padding
//        "SGVsbG8gd29ybGQ=", // base64 with padding character "="
//        "SGVsbG8/d29ybGQ=", // base64url with invalid "=" padding
//        "Zm9vYmFy==", // improper padding
        "SGVsbG8@d29ybGQ", // invalid character "@"
        "SGVsbG8=d29ybGQ", // invalid "=" in middle
        "SGVsbG8$d29ybGQ", // invalid character "$"
        "SGVsbG8^d29ybGQ", // invalid character "^"
        "Zm9vYmFy\n", // invalid newline character
        "Zm9vYmFy ", // invalid space character
        "Zm9vYmFy\t", // invalid tab character
        "Zm9vYmFy\r", // invalid carriage return character
//        "Zm9vYmFy\v", // invalid vertical tab character
    ]

    func testRoundtrip() {
        for (base64url, data) in validBase64UrlTestCases {
            let fromData = Base64URL(from: data)
            XCTAssertEqual(fromData.base64URLString, base64url)
            XCTAssertEqual(fromData.toData()!, data)

            let fromString = Base64URL(base64url)
            XCTAssertEqual(fromString.toData()!, data)
            XCTAssertEqual(Base64URL(from: fromString.toData()!).base64URLString, base64url)
        }
    }

    func testBase64URLDecoding() {
        let decoder = JSONDecoder()
        for (base64url, expected) in validBase64UrlTestCases {
//            let base64url = Base64URL(from: data)
//            XCTAssertEqual(expected)
            let actual = try! decoder.decode(Base64URL.self, from: "\"\(base64url)\"".data(using: .utf8)!)
            XCTAssertEqual(actual.toData()!, expected)
        }
    }

    func testInvalidBase64URLData() {
        // This will change in a moment
        for invalid in invalidBase64UrlStrings {
            let base64URL = Base64URL(invalid)
            XCTAssertNil(base64URL.toData(), "\(invalid) became \(base64URL.toData()!.base64EncodedString())")
        }
    }
}
