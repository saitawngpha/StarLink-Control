import Foundation

final class StarlinkRemoteClient {
    private let session: URLSession
    private let authURL = URL(string: "https://api.starlink.com/auth-rp/auth/user")!
    private let serviceLinesURL = URL(string: "https://api.starlink.com/webagg/v2/accounts/service-lines?limit=100&page=0&isConverting=false&onlyActive=false&onlyNoUts=false")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadProfile(cookieInput: String) async throws -> (profile: RemoteStarlinkProfile, refreshedCookie: String) {
        let cookieHeader = try normalizedCookieHeader(from: cookieInput)
        let account = try await fetchAccount(cookieHeader: cookieHeader)
        let serviceLines = try await fetchServiceLines(cookieHeader: cookieHeader)

        guard let serviceLine = serviceLines.content?.results?.first else {
            throw StarlinkRemoteClientError.noServiceLines
        }

        let dish = serviceLine.userTerminals?.first
        let router = dish?.routers?.first
        let accountName = account.name?.nonEmpty
            ?? [account.givenName, account.familyName].compactMap(\.?.nonEmpty).joined(separator: " ").nonEmpty
            ?? "Starlink Account"

        let profile = RemoteStarlinkProfile(
            accountName: accountName,
            email: account.email?.nonEmpty ?? "Unknown email",
            accountID: account.accountId?.nonEmpty ?? "Unknown account",
            serviceLine: serviceLine.serviceLineNumber?.nonEmpty ?? "Unknown service line",
            planName: serviceLine.subscription?.productDescription?.nonEmpty ?? serviceLine.displayName?.nonEmpty ?? "Starlink",
            dishID: dish?.userTerminalId?.prefixedIfNeeded("ut") ?? "Unknown dish",
            routerID: router?.routerId?.prefixedIfNeeded("Router-") ?? "Unknown router",
            latitude: dish?.latitude ?? 0,
            longitude: dish?.longitude ?? 0,
            address: serviceLine.serviceAddress?.formattedAddress?.nonEmpty ?? "No service address"
        )

        return (profile, cookieHeader)
    }

    private func fetchAccount(cookieHeader: String) async throws -> StarlinkAccountResponse {
        var request = URLRequest(url: authURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(xsrfToken(from: cookieHeader), forHTTPHeaderField: "x-xsrf-token")
        request.setValue("okhttp/4.9.2", forHTTPHeaderField: "X-User-Agent")

        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(StarlinkAccountResponse.self, from: data)
    }

    private func fetchServiceLines(cookieHeader: String) async throws -> StarlinkServiceLinesResponse {
        var request = URLRequest(url: serviceLinesURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(xsrfToken(from: cookieHeader), forHTTPHeaderField: "x-xsrf-token")
        request.setValue("okhttp/4.9.2", forHTTPHeaderField: "X-User-Agent")

        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(StarlinkServiceLinesResponse.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StarlinkRemoteClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw StarlinkRemoteClientError.unauthorized
        default:
            throw StarlinkRemoteClientError.httpStatus(httpResponse.statusCode)
        }
    }

    private func normalizedCookieHeader(from input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw StarlinkRemoteClientError.emptyCookie
        }

        if let data = trimmed.data(using: .utf8),
           let jsonCookies = try? JSONDecoder().decode([BrowserCookie].self, from: data) {
            let header = jsonCookies
                .filter { $0.name.isEmpty == false && $0.value.isEmpty == false }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")

            guard header.isEmpty == false else {
                throw StarlinkRemoteClientError.emptyCookie
            }

            return header
        }

        return trimmed
    }

    private func xsrfToken(from cookieHeader: String) -> String {
        cookieHeader
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("XSRF-TOKEN=") }?
            .replacingOccurrences(of: "XSRF-TOKEN=", with: "") ?? ""
    }
}

private struct BrowserCookie: Decodable {
    var name: String
    var value: String
}

enum StarlinkRemoteClientError: LocalizedError {
    case emptyCookie
    case invalidResponse
    case unauthorized
    case httpStatus(Int)
    case noServiceLines

    var errorDescription: String? {
        switch self {
        case .emptyCookie:
            "Paste the Starlink browser cookie header or exported cookie JSON first."
        case .invalidResponse:
            "Starlink returned an invalid response."
        case .unauthorized:
            "Starlink rejected the cookie. Log in again in a browser and paste a fresh cookie."
        case .httpStatus(let code):
            "Starlink returned HTTP \(code)."
        case .noServiceLines:
            "No Starlink service lines were found for this account."
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }

    func prefixedIfNeeded(_ prefix: String) -> String {
        hasPrefix(prefix) ? self : "\(prefix)\(self)"
    }
}
