import Foundation
import os

/// Internal API call wrapper
struct SnapAuthClient {
    private let urlBase: URL
    private let publishableKey: String
    private let logger: Logger?

    init(urlBase: URL, publishableKey: String, logger: Logger?) {
        self.urlBase = urlBase
        self.publishableKey = publishableKey
        self.logger = logger
    }

    /// Auth header generation
    var basic: String {
        return "Basic " + Data("\(publishableKey):".utf8).base64EncodedString()
    }

    func makeRequest<T>(
        path: String,
        body: Encodable,
        type: T.Type
    ) async -> Result<T, SnapAuthError> where T: Decodable {
        let url = urlBase.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(basic, forHTTPHeaderField: "Authorization")

        do {
            let json = try JSONEncoder().encode(body)
            request.httpBody = json
            logger?.debug("--> \(String(decoding: json, as: UTF8.self))")
        } catch {
            return .failure(.sdkEncodingError)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.networkInterruption)
        }

        let jsonString = String(data: data, encoding: .utf8)
        logger?.debug("<-- \(jsonString ?? "not a string")")

        // This allows skipping custom decodable implementations
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let parsed = try? decoder.decode(SAWrappedResponse<T>.self, from: data)
        else {
            logger?.error("Decoding request failed")
            // TODO: return some sort of failure SAResponse
            return .failure(.malformedResposne)
        }

        guard let wrapped = parsed.result else {
            // TODO: match all of the docuemented error types
            return .failure(.badRequest)
        }
        return .success(wrapped)
    }

}
