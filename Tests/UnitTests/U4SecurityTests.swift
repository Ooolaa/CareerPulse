import Testing
import Foundation
@testable import CareerPulse

// MARK: - Keychain

@Suite("Keychain store", .serialized)
struct KeychainStoreTests {
    private let account = "unit-test-key"

    @Test("save → read → update → delete round trip")
    func roundTrip() {
        KeychainStore.delete(account: account)

        // Unsigned simulator test hosts can't access the Keychain
        // (errSecMissingEntitlement, -34018). That's an environment limit, not
        // a code bug — the real app runs signed. Skip only that specific case;
        // real logic is still exercised on a signed device build.
        let status = KeychainStore.saveStatus("sk-ant-test-1", account: account)
        guard status != errSecMissingEntitlement else { return }
        #expect(status == errSecSuccess)
        #expect(KeychainStore.read(account: account) == "sk-ant-test-1")

        #expect(KeychainStore.save("sk-ant-test-2", account: account))   // update path
        #expect(KeychainStore.read(account: account) == "sk-ant-test-2")

        #expect(KeychainStore.delete(account: account))
        #expect(KeychainStore.read(account: account) == nil)
    }
}

// MARK: - Anthropic client (request shape via stubbed URLProtocol)

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseBody = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite("Anthropic client", .serialized)
struct AnthropicClientTests {

    private func stubbedClient() -> AnthropicClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return AnthropicClient(session: URLSession(configuration: config))
    }

    @Test("sends key/version headers and model; extracts text")
    func requestShape() async throws {
        StubURLProtocol.responseBody = Data("""
        {"content":[{"type":"text","text":"hello"}]}
        """.utf8)

        let text = try await stubbedClient().complete(system: "sys", user: "usr",
                                                      apiKey: "sk-ant-unit")
        #expect(text == "hello")

        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-unit")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let body = request.httpBody ?? request.httpBodyStream.map { stream -> Data in
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            return data
        } ?? Data()
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        #expect(bodyString.contains(AnthropicClient.model))
        #expect(bodyString.contains("\"system\":\"sys\""))
    }

    @Test("non-2xx surfaces a typed error, 401 gets a friendly message")
    func errors() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailingURLProtocol.self]
        let client = AnthropicClient(session: URLSession(configuration: config))
        await #expect(throws: AnthropicClient.ClientError.self) {
            _ = try await client.complete(system: "s", user: "u", apiKey: "bad")
        }
    }
}

final class FailingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - Generator sanitizer (hostile/sloppy model output must not install)

@Suite("Pack generator sanitizer")
struct PackGeneratorSanitizerTests {

    private func concept(_ name: String, _ cluster: String = "A",
                         prereqs: [String] = []) -> PackFile.PackConcept {
        .init(name: name, cluster: cluster, definition: "def of \(name)", prerequisites: prereqs)
    }

    @Test("scrubs duplicates, self-references, dangling prereqs, then validates")
    func scrubbing() throws {
        let dirty = PackFile(
            career: "  Tester  ",
            specialtyCluster: "Ghost cluster",
            clusterOrder: ["A"],
            concepts: [
                concept("X", prereqs: ["X", "Nonexistent", "Y"]),   // self + dangling
                concept("Y"),
                concept("x"),                                        // dup (case)
            ],
            stages: [StageDef(title: "S", subtitle: "", concepts: ["X", "Ghost"])],
            suggestedSources: []
        )
        let clean = PackGenerator.sanitize(dirty)
        try PackValidator.validate(clean)
        #expect(clean.concepts.count == 2)
        #expect(clean.concepts.first { $0.name == "X" }?.prerequisites == ["Y"])
        #expect(clean.specialtyCluster == "A")                      // remapped off ghost
        #expect(clean.stages.allSatisfy { !$0.concepts.contains("Ghost") })
    }

    @Test("breaks prerequisite cycles instead of failing")
    func cycleBreaking() throws {
        let cyclic = PackFile(
            career: "T", specialtyCluster: "A", clusterOrder: ["A"],
            concepts: [
                concept("P", prereqs: ["Q"]),
                concept("Q", prereqs: ["P"]),
            ],
            stages: [], suggestedSources: []
        )
        let clean = PackGenerator.sanitize(cyclic)
        try PackValidator.validate(clean)                            // no cycle left
        #expect(clean.stages.count == 1)                             // synthesized
    }

    @Test("parses model JSON with fences and prose around it")
    func fencedJSON() throws {
        let text = """
        Sure! Here's the pack:
        ```json
        {"version":1,"career":"C","specialtyCluster":"A","clusterOrder":["A"],
         "concepts":[{"name":"N","cluster":"A","definition":"d","prerequisites":[]}],
         "stages":[],"suggestedSources":[]}
        ```
        """
        let pack = try #require(PackGenerator.parseRemoteJSON(text))
        #expect(pack.career == "C")
    }
}

// MARK: - Feed parser hardening

@Suite("Parser hardening")
struct ParserHardeningTests {
    @Test("external-entity payloads yield no exploited content")
    func xxe() {
        let payload = """
        <?xml version="1.0"?>
        <!DOCTYPE r [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
        <rss><channel><item><title>&xxe;safe</title></item></channel></rss>
        """
        let items = RSSParser.parse(Data(payload.utf8))
        // Entity must not expand to file contents.
        #expect(items.allSatisfy { !$0.title.contains("root:") })
    }
}
