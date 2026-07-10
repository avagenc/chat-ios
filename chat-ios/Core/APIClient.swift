//
//  APIClient.swift
//  chat-ios
//
//  HTTP client for the Avagenc Chat backend.
//  Every request carries credentials + the `time-zone` (IANA) header.
//

import Foundation

struct ApiError: Error, Equatable {
    let status: Int
    let detail: String
}

/// Per-request Firebase ID token source (Authorization: Bearer).
protocol APICredentialProvider: AnyObject {
    func bearerToken() async throws -> String
}

final class APIClient {
    static let shared = APIClient()

    weak var credentialProvider: APICredentialProvider?

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        // Roomy enough for the longest agent turn (see `post(timeout:)`).
        config.timeoutIntervalForResource = 360
        // Chat data is always dynamic; the backend sends no Cache-Control, so
        // URLSession may apply heuristic caching to identical URLs during
        // polling (`/sessions/messages?lastn=200`), serving a stale snapshot
        // and hiding agent replies that just landed. Disable caching entirely
        // so every poll truly hits the server.
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func get<T: Decodable>(
        _ type: T.Type, _ path: String, timeout: TimeInterval? = nil
    ) async throws -> T? {
        let data = try await raw(path: path, timeout: timeout)
        guard let data, !data.isEmpty else { return nil }
        // Surface decode errors as ApiError — so callers (e.g. fetchThread)
        // don't mistake a schema mismatch for "empty data".
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError(status: -1, detail: "decode failed: \(error)")
        }
    }

    @discardableResult
    func post(
        _ path: String, body: some Encodable, timeout: TimeInterval? = nil
    ) async throws -> Data? {
        try await raw(
            path: path, method: "POST",
            bodyData: JSONEncoder().encode(body), timeout: timeout
        )
    }

    func delete(_ path: String) async throws {
        _ = try await raw(path: path, method: "DELETE")
    }

    func raw(
        path: String, method: String = "GET",
        bodyData: Data? = nil, timeout: TimeInterval? = nil
    ) async throws -> Data? {
        guard let provider = credentialProvider else {
            throw ApiError(status: 401, detail: "not authenticated")
        }
        let token = try await provider.bearerToken()

        let base = AppConfig.apiBase.replacingOccurrences(
            of: "/+$", with: "", options: .regularExpression
        )
        guard let url = URL(string: base + path) else {
            throw ApiError(status: 0, detail: "invalid url")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let timeout { req.timeoutInterval = timeout }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(TimeZone.current.identifier, forHTTPHeaderField: "time-zone")
        if let bodyData {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ApiError(status: 0, detail: "no response")
        }
        if http.statusCode == 204 { return nil }
        guard (200 ..< 300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            #if DEBUG
            print("[api] \(method) \(path) → \(http.statusCode): \(detail ?? "(no detail)")")
            #endif
            throw ApiError(status: http.statusCode, detail: detail ?? "request failed")
        }
        return data
    }
}
