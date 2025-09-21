import Foundation
import os

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
}

public struct HTTPRequest {
    public var url: URL
    public var method: HTTPMethod
    public var headers: [String: String]
    public var body: Data?
    public var cachePolicy: URLRequest.CachePolicy
    public var timeout: TimeInterval?
    public var maximumRetryCount: Int?

    public init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeout: TimeInterval? = nil,
        maximumRetryCount: Int? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.cachePolicy = cachePolicy
        self.timeout = timeout
        self.maximumRetryCount = maximumRetryCount
    }
}

public struct HTTPResponse {
    public let data: Data
    public let response: HTTPURLResponse

    public var statusCode: Int { response.statusCode }
    public var headers: [AnyHashable: Any] { response.allHeaderFields }
}

public enum HTTPClientError: Error, Equatable {
    case invalidResponse
    case unacceptableStatus(code: Int, data: Data)
    case transport(underlying: Error)

    public static func == (lhs: HTTPClientError, rhs: HTTPClientError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse):
            return true
        case let (.unacceptableStatus(code1, data1), .unacceptableStatus(code2, data2)):
            return code1 == code2 && data1 == data2
        case let (.transport(underlying: err1), .transport(underlying: err2)):
            return (err1 as NSError) == (err2 as NSError)
        default:
            return false
        }
    }
}

public protocol NetworkLogger {
    func logRequest(_ request: URLRequest, attempt: Int)
    func logResponse(_ response: HTTPResponse, request: URLRequest, attempt: Int)
    func logFailure(_ error: Error, request: URLRequest, attempt: Int)
}

struct DefaultNetworkLogger: NetworkLogger {
    private let logger = Logger(subsystem: "tsuncap.network", category: "http")

    func logRequest(_ request: URLRequest, attempt: Int) {
        logger.debug("[Attempt \(attempt)] Request \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
    }

    func logResponse(_ response: HTTPResponse, request: URLRequest, attempt: Int) {
        logger.debug("[Attempt \(attempt)] Response status \(response.statusCode) for \(request.url?.absoluteString ?? "")")
    }

    func logFailure(_ error: Error, request: URLRequest, attempt: Int) {
        logger.error("[Attempt \(attempt)] Error \(error.localizedDescription) for \(request.url?.absoluteString ?? "")")
    }
}

public struct HTTPClientConfiguration {
    public var defaultTimeout: TimeInterval
    public var maxRetryCount: Int
    public var retryDelay: (Int) -> TimeInterval

    public init(
        defaultTimeout: TimeInterval = 30,
        maxRetryCount: Int = 2,
        retryDelay: @escaping (Int) -> TimeInterval = { attempt in
            // Exponential back-off: 0.5, 1.0, 2.0 ...
            pow(2.0, Double(attempt)) * 0.5
        }
    ) {
        self.defaultTimeout = defaultTimeout
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
    }
}

public final class URLSessionHTTPClient {
    private let session: URLSession
    private let configuration: HTTPClientConfiguration
    private let logger: NetworkLogger
    private let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .notConnectedToInternet,
        .internationalRoamingOff,
        .callIsActive,
        .dataNotAllowed,
        .requestBodyStreamExhausted,
        .backgroundSessionWasDisconnected
    ]

    public init(
        session: URLSession = .shared,
        configuration: HTTPClientConfiguration = HTTPClientConfiguration(),
        logger: NetworkLogger? = nil
    ) {
        self.session = session
        self.configuration = configuration
        self.logger = logger ?? DefaultNetworkLogger()
    }

    @discardableResult
    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let maxRetries = request.maximumRetryCount ?? configuration.maxRetryCount
        var attempt = 0

        while true {
            attempt += 1
            let urlRequest = makeURLRequest(from: request)
            logger.logRequest(urlRequest, attempt: attempt)

            do {
                let (data, rawResponse) = try await session.data(for: urlRequest)
                guard let httpResponse = rawResponse as? HTTPURLResponse else {
                    throw HTTPClientError.invalidResponse
                }

                let response = HTTPResponse(data: data, response: httpResponse)

                guard (200...299).contains(httpResponse.statusCode) else {
                    let error = HTTPClientError.unacceptableStatus(code: httpResponse.statusCode, data: data)
                    try await handleFailure(error, request: urlRequest, attempt: attempt, maxRetries: maxRetries)
                    continue
                }

                logger.logResponse(response, request: urlRequest, attempt: attempt)
                return response
            } catch {
                let wrappedError: HTTPClientError
                if let clientError = error as? HTTPClientError {
                    wrappedError = clientError
                } else {
                    wrappedError = .transport(underlying: error)
                }

                try await handleFailure(wrappedError, request: urlRequest, attempt: attempt, maxRetries: maxRetries)
            }
        }
    }

    private func handleFailure(
        _ error: HTTPClientError,
        request: URLRequest,
        attempt: Int,
        maxRetries: Int
    ) async throws {
        logger.logFailure(error, request: request, attempt: attempt)

        guard attempt <= maxRetries, shouldRetry(after: error) else {
            throw error
        }

        let delaySeconds = configuration.retryDelay(attempt)
        let positiveDelay = max(delaySeconds, 0)
        if positiveDelay > 0 {
            let nanoseconds = UInt64((positiveDelay * 1_000_000_000).rounded())
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    private func shouldRetry(after error: HTTPClientError) -> Bool {
        switch error {
        case let .unacceptableStatus(code, _):
            return (500...599).contains(code)
        case let .transport(underlying):
            if let urlError = underlying as? URLError {
                return retryableURLErrorCodes.contains(urlError.code)
            }
            return false
        case .invalidResponse:
            return false
        }
    }

    private func makeURLRequest(from request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(
            url: request.url,
            cachePolicy: request.cachePolicy,
            timeoutInterval: request.timeout ?? configuration.defaultTimeout
        )
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpBody = request.body
        return urlRequest
    }
}
