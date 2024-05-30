@testable import SnapAuth
import XCTest

final class Base64URLTests: XCTestCase {
    let validBase64UrlTestCases: [(String, Data)] = [
        ("", Data()),
        ("Zg", "f".data(using: .utf8)!),
        ("Zm8", "fo".data(using: .utf8)!),
        ("Zm9v", "foo".data(using: .utf8)!),
        ("Zm9vYg", "foob".data(using: .utf8)!),
        ("Zm9vYmE", "fooba".data(using: .utf8)!),
        ("Zm9vYmFy", "foobar".data(using: .utf8)!),
        ("SGVsbG8_d29ybGQ", "Hello?world".data(using: .utf8)!),
        ("SGVsbG8gd29ybGQ", "Hello world".data(using: .utf8)!),
        ("Zm9vYmFyCg", "foobar\n".data(using: .utf8)!),
//            ("Zm9vYmFyCg==", "foobar\n".data(using: .utf8)!),
        ("MTIzNDU2Nzg5MA", "1234567890".data(using: .utf8)!),
        ("L3Vzci9iaW4vZW52Cg", "/usr/bin/env\n".data(using: .utf8)!),
        ("U29tZSB0ZXh0IHdpdGggdHdvIHNwYWNl", "Some text with two space".data(using: .utf8)!),
        ("U29tZSB0ZXh0IHdpdGggdGhyZWUgc3BhY2Vz", "Some text with three spaces".data(using: .utf8)!),
        // Binary data
        ("AAEC", Data([0x00, 0x01, 0x02])),
        ("AQIDBAUGBwgJCgsMDQ4P", Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F])),
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
    ]

    func testRoundtrip() throws {
        for (base64url, data) in validBase64UrlTestCases {
            let fromData = Base64URL(from: data)
            XCTAssertEqual(fromData.string, base64url)
            XCTAssertEqual(fromData.data, data)
            XCTAssertEqual(try Base64URL(fromData.string).data, data)

            let fromString = try Base64URL(base64url)
            XCTAssertEqual(fromString.data, data)
            XCTAssertEqual(fromString.string, base64url)
            XCTAssertEqual(Base64URL(from: fromString.data).string, base64url)
        }
    }

    func testBase64URLDecoding() throws {
        let decoder = JSONDecoder()
        for (base64url, expected) in validBase64UrlTestCases {
            let json = "\"\(base64url)\"" // Wrap in quotes
            let actual = try decoder.decode(Base64URL.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(actual.data, expected, base64url)
        }
    }

    func testInvalidBase64URLData() {
        // This will change in a moment
        for invalid in invalidBase64UrlStrings {
            XCTAssertNil(try? Base64URL(invalid))
        }
    }
}
