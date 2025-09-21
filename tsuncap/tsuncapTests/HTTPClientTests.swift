import XCTest
@testable import tsuncap

final class HTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    func testRespectsCustomTimeout() async throws {
        MockURLProtocol.enqueue(.success(data: Data("{}".utf8), statusCode: 200))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let client = URLSessionHTTPClient(
            session: session,
            configuration: HTTPClientConfiguration(defaultTimeout: 5, maxRetryCount: 0)
        )

        let request = HTTPRequest(
            url: URL(string: "https://example.com")!,
            timeout: 12
        )

        _ = try await client.send(request)

        let recordedTimeouts = MockURLProtocol.recordedRequests.map { $0.timeoutInterval }
        XCTAssertEqual(recordedTimeouts, [12])
    }

    func testRetriesOnTimeoutAndSucceeds() async throws {
        MockURLProtocol.enqueue(.failure(URLError(.timedOut)))
        MockURLProtocol.enqueue(.success(data: Data("retry".utf8), statusCode: 200))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let logger = TestNetworkLogger()
        let client = URLSessionHTTPClient(
            session: session,
            configuration: HTTPClientConfiguration(defaultTimeout: 1, maxRetryCount: 1, retryDelay: { _ in 0 }),
            logger: logger
        )

        let request = HTTPRequest(url: URL(string: "https://example.com/resource")!, timeout: 1)

        let response = try await client.send(request)

        XCTAssertEqual(String(data: response.data, encoding: .utf8), "retry")
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 2)
        XCTAssertEqual(logger.requestAttempts, [1, 2])
        XCTAssertEqual(logger.failureAttempts, [1])
        XCTAssertEqual(logger.successAttempts, [2])
    }

    func testRetriesOnServerErrorAndSucceeds() async throws {
        MockURLProtocol.enqueue(.success(data: Data("error".utf8), statusCode: 500))
        MockURLProtocol.enqueue(.success(data: Data("ok".utf8), statusCode: 200))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let client = URLSessionHTTPClient(
            session: session,
            configuration: HTTPClientConfiguration(defaultTimeout: 1, maxRetryCount: 1, retryDelay: { _ in 0 })
        )

        let request = HTTPRequest(url: URL(string: "https://example.com/500")!, timeout: 1)

        let response = try await client.send(request)

        XCTAssertEqual(String(data: response.data, encoding: .utf8), "ok")
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 2)
    }

    func testExhaustsRetriesAndThrowsTransportError() async {
        MockURLProtocol.enqueue(.failure(URLError(.timedOut)))
        MockURLProtocol.enqueue(.failure(URLError(.timedOut)))
        MockURLProtocol.enqueue(.failure(URLError(.timedOut)))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let client = URLSessionHTTPClient(
            session: session,
            configuration: HTTPClientConfiguration(defaultTimeout: 1, maxRetryCount: 2, retryDelay: { _ in 0 })
        )

        let request = HTTPRequest(url: URL(string: "https://example.com/timeout")!, timeout: 1)

        do {
            _ = try await client.send(request)
            XCTFail("Expected to throw")
        } catch let HTTPClientError.transport(underlying as URLError) {
            XCTAssertEqual(underlying.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 3)
    }

    func testDoesNotRetryOnClientErrorStatus() async {
        MockURLProtocol.enqueue(.success(data: Data("nope".utf8), statusCode: 404))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let client = URLSessionHTTPClient(
            session: session,
            configuration: HTTPClientConfiguration(defaultTimeout: 1, maxRetryCount: 3, retryDelay: { _ in 0 })
        )

        let request = HTTPRequest(url: URL(string: "https://example.com/404")!, timeout: 1)

        do {
            _ = try await client.send(request)
            XCTFail("Expected to throw")
        } catch let HTTPClientError.unacceptableStatus(code, data) {
            XCTAssertEqual(code, 404)
            XCTAssertEqual(String(data: data, encoding: .utf8), "nope")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1)
    }
}

private final class TestNetworkLogger: NetworkLogger {
    private(set) var requestAttempts: [Int] = []
    private(set) var successAttempts: [Int] = []
    private(set) var failureAttempts: [Int] = []

    func logRequest(_ request: URLRequest, attempt: Int) {
        requestAttempts.append(attempt)
    }

    func logResponse(_ response: HTTPResponse, request: URLRequest, attempt: Int) {
        successAttempts.append(attempt)
    }

    func logFailure(_ error: Error, request: URLRequest, attempt: Int) {
        failureAttempts.append(attempt)
    }
}

private final class MockURLProtocol: URLProtocol {
    enum MockResponse {
        case success(data: Data, statusCode: Int)
        case failure(Error)
    }

    private struct Response {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    private static let queue = DispatchQueue(label: "MockURLProtocol.queue")
    private static var responses: [Response] = []
    private(set) static var recordedRequests: [URLRequest] = []

    static func reset() {
        queue.sync {
            responses.removeAll()
            recordedRequests.removeAll()
        }
    }

    static func enqueue(_ response: MockResponse) {
        let wrapped: Response

        switch response {
        case let .success(data, statusCode):
            wrapped = Response(
                data: data,
                response: HTTPURLResponse(
                    url: URL(string: "https://example.com")!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil
            )
        case let .failure(error):
            wrapped = Response(data: nil, response: nil, error: error)
        }

        queue.sync {
            responses.append(wrapped)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = Self.dequeue()

        Self.queue.sync {
            Self.recordedRequests.append(request)
        }

        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let urlResponse = response.response {
            client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
        }

        if let data = response.data {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // No-op
    }

    private static func dequeue() -> Response {
        queue.sync {
            guard !responses.isEmpty else {
                fatalError("No more mock responses queued")
            }
            return responses.removeFirst()
        }
    }
}
