import Foundation

actor GitHubAPIClient {
    private let session: URLSession
    private var pat: String
    private(set) var rateLimitRemaining: Int = 5000
    private(set) var rateLimitReset: Date = .distantFuture

    init(pat: String) {
        self.pat = pat
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Accept": "application/vnd.github+json"]
        self.session = URLSession(configuration: config)
    }

    func updatePAT(_ newPAT: String) {
        self.pat = newPAT
    }

    // MARK: - User

    func validateToken() async throws -> GitHubUser {
        return try await request(endpoint: "/user")
    }

    // MARK: - Repositories

    func searchRepos(query: String) async throws -> GitHubRepoSearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(endpoint: "/search/repositories?q=\(encoded)&per_page=20")
    }

    // MARK: - Issues

    func fetchIssues(repo: String, state: String = "open", page: Int = 1) async throws -> [GitHubIssue] {
        return try await request(endpoint: "/repos/\(repo)/issues?state=\(state)&per_page=30&page=\(page)")
    }

    func getIssue(repo: String, number: Int) async throws -> GitHubIssue {
        return try await request(endpoint: "/repos/\(repo)/issues/\(number)")
    }

    // MARK: - Internal

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        let urlString = Constants.gitHubAPIBaseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw GitHubAPIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        // Track rate limits
        if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remainingInt = Int(remaining) {
            rateLimitRemaining = remainingInt
        }
        if let reset = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTimestamp = TimeInterval(reset) {
            rateLimitReset = Date(timeIntervalSince1970: resetTimestamp)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

struct GitHubUser: Codable {
    let login: String
    let name: String?
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarURL = "avatar_url"
    }
}

enum GitHubAPIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .httpError(let code, let message):
            return "GitHub API error (\(code)): \(message)"
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded. Please wait."
        }
    }
}
