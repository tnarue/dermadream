//
//  RemoteUserRecordsService.swift
//  dermadream
//
//  HTTP client for the `user_records` collection in MongoDB.
//
//  iOS can't speak the MongoDB wire protocol directly, so we talk to a
//  small REST bridge running on the developer Mac (or any backend).
//  Shape expected by the bridge:
//
//      GET  {USER_RECORDS_BASE_URL}/user_records/{id}
//           -> 200 { ...UserRecord JSON... }
//           -> 404 when the user doesn't exist
//
//  The base URL lives in `Config.xcconfig` so it can point at a LAN IP
//  (e.g. `http://192.168.1.12:3000`) for on-device testing. Localhost
//  will NOT work when the app runs on a physical iPhone, since
//  "localhost" resolves to the phone itself.
//

import Foundation

// MARK: - Errors

enum RemoteUserRecordsError: LocalizedError {
    case missingBaseURL(String)
    case invalidURL
    case http(status: Int, body: String)
    case notFound(String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL(let detail):
            return "USER_RECORDS_BASE_URL is not configured. \(detail)"
        case .invalidURL:
            return "Could not build a valid user_records URL."
        case .http(let status, let body):
            return "user_records HTTP error \(status). \(body)"
        case .notFound(let id):
            return "No user record found for userId \"\(id)\" on the remote bridge."
        case .decoding(let detail):
            return "Failed to decode user_records response: \(detail)"
        case .transport(let detail):
            return "Network error reaching MongoDB bridge: \(detail)"
        }
    }
}

// MARK: - Service

final class RemoteUserRecordsService: UserRecordsProviding {
    private let session: URLSession
    private let baseURL: URL

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Convenience initializer: returns `nil` if the base URL isn't
    /// configured or is malformed, so callers can fall back to the
    /// in-memory mock cleanly.
    static func configuredFromEnvironment(
        session: URLSession = .shared
    ) -> RemoteUserRecordsService? {
        guard
            let raw = try? APIConfig.userRecordsBaseURLThrowing(),
            let url = URL(string: raw)
        else {
            return nil
        }
        return RemoteUserRecordsService(baseURL: url, session: session)
    }

    // MARK: UserRecordsProviding

    func findUserRecord(userId: String) async throws -> UserRecord {
        let url = try buildURL(for: userId)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RemoteUserRecordsError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RemoteUserRecordsError.transport("Response was not an HTTP response.")
        }

        if http.statusCode == 404 {
            throw RemoteUserRecordsError.notFound(userId)
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw RemoteUserRecordsError.http(status: http.statusCode, body: body)
        }

        do {
            return try JSONDecoder().decode(UserRecord.self, from: data)
        } catch {
            throw RemoteUserRecordsError.decoding(error.localizedDescription)
        }
    }

    // MARK: - URL

    private func buildURL(for userId: String) throws -> URL {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RemoteUserRecordsError.invalidURL
        }

        let encoded = trimmed.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? trimmed

        guard let url = URL(
            string: "user_records/\(encoded)",
            relativeTo: baseURL
        )?.absoluteURL else {
            throw RemoteUserRecordsError.invalidURL
        }
        return url
    }
}

// MARK: - Default selection

/// Central factory that picks the correct `UserRecordsProviding`
/// implementation at runtime:
///
/// - If `USER_RECORDS_BASE_URL` is set in `Config.xcconfig` (and therefore
///   in `Info.plist`), we use `RemoteUserRecordsService` for both
///   simulator and device runs.
/// - Otherwise we fall back to the in-memory `MockUserRecordsDB`.
enum UserRecordsService {
    static var current: UserRecordsProviding {
        if let remote = RemoteUserRecordsService.configuredFromEnvironment() {
            return remote
        }
        return MockUserRecordsDB.shared
    }
}
