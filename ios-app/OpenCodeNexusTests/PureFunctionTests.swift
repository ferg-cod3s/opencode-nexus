import XCTest
@testable import OpenCodeNexus

@MainActor
final class PureFunctionTests: XCTestCase {

    // MARK: - formatTokenCount

    func testFormatTokenCountBelow1000() {
        let msg = try! decodeTestMsg(id: "1", text: "hi")
        let bubble = MessageBubble(message: msg)
        XCTAssertEqual(bubble.formatTokenCount(999), "999")
    }

    func testFormatTokenCountExactly1000() {
        let msg = try! decodeTestMsg(id: "1", text: "hi")
        let bubble = MessageBubble(message: msg)
        XCTAssertEqual(bubble.formatTokenCount(1000), "1.0k")
    }

    func testFormatTokenCount1500() {
        let msg = try! decodeTestMsg(id: "1", text: "hi")
        let bubble = MessageBubble(message: msg)
        XCTAssertEqual(bubble.formatTokenCount(1500), "1.5k")
    }

    func testFormatTokenCount10000() {
        let msg = try! decodeTestMsg(id: "1", text: "hi")
        let bubble = MessageBubble(message: msg)
        XCTAssertEqual(bubble.formatTokenCount(10000), "10.0k")
    }

    func testFormatTokenCountZero() {
        let msg = try! decodeTestMsg(id: "1", text: "hi")
        let bubble = MessageBubble(message: msg)
        XCTAssertEqual(bubble.formatTokenCount(0), "0")
    }

    // MARK: - parseResults

    func testParseResultsBasicColonFormat() {
        let view = SearchToolView(input: nil, output: nil, icon: "magnifyingglass", color: .blue)
        let results = view.parseResults("file.swift:42:match text")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].file, "file.swift")
        XCTAssertEqual(results[0].line, "42")
        XCTAssertEqual(results[0].text, "match text")
    }

    func testParseResultsFileOnly() {
        let view = SearchToolView(input: nil, output: nil, icon: "magnifyingglass", color: .blue)
        let results = view.parseResults("file.swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].file, "file.swift")
        XCTAssertNil(results[0].line)
        XCTAssertNil(results[0].text)
    }

    func testParseResultsMultipleLines() {
        let view = SearchToolView(input: nil, output: nil, icon: "magnifyingglass", color: .blue)
        let results = view.parseResults("a.swift:1:text1\nb.swift:2:text2")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].file, "a.swift")
        XCTAssertEqual(results[1].file, "b.swift")
    }

    func testParseResultsEmptyLinesSkipped() {
        let view = SearchToolView(input: nil, output: nil, icon: "magnifyingglass", color: .blue)
        let results = view.parseResults("file.swift:1:text\n\n\nother.swift:2:code")
        XCTAssertEqual(results.count, 2)
    }

    func testParseResultsEmptyString() {
        let view = SearchToolView(input: nil, output: nil, icon: "magnifyingglass", color: .blue)
        let results = view.parseResults("")
        XCTAssertTrue(results.isEmpty)
    }

    func testParseResultsWhitespaceOnlyLines() {
        let view = SearchToolView(input: nil, output: nil, icon: "magnifyingglass", color: .blue)
        let results = view.parseResults("  \n  \nfile.swift:1:match")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - groupedModels

    func testGroupedModelsGroupsByProvider() {
        let models: [(providerID: String, modelID: String, name: String)] = [
            ("openai", "gpt-4", "GPT-4"),
            ("anthropic", "claude", "Claude"),
            ("openai", "gpt-3.5", "GPT-3.5"),
        ]
        let providers = [
            ProviderInfo(id: "openai", name: "OpenAI", models: nil),
            ProviderInfo(id: "anthropic", name: "Anthropic", models: nil),
        ]
        let groups = groupedModels(models, providers: providers)
        XCTAssertEqual(groups.count, 2)
    }

    func testGroupedModelsSortsByProviderName() {
        let models: [(providerID: String, modelID: String, name: String)] = [
            ("z", "m1", "M1"),
            ("a", "m2", "M2"),
        ]
        let providers = [
            ProviderInfo(id: "z", name: "Zeta", models: nil),
            ProviderInfo(id: "a", name: "Alpha", models: nil),
        ]
        let groups = groupedModels(models, providers: providers)
        XCTAssertEqual(groups[0].providerName, "Alpha")
        XCTAssertEqual(groups[1].providerName, "Zeta")
    }

    func testGroupedModelsSortsModelsByName() {
        let models: [(providerID: String, modelID: String, name: String)] = [
            ("p", "b", "Beta"),
            ("p", "a", "Alpha"),
        ]
        let providers = [ProviderInfo(id: "p", name: "P", models: nil)]
        let groups = groupedModels(models, providers: providers)
        XCTAssertEqual(groups[0].models[0].name, "Alpha")
        XCTAssertEqual(groups[0].models[1].name, "Beta")
    }

    func testGroupedModelsEmptyInput() {
        let groups = groupedModels([], providers: [])
        XCTAssertTrue(groups.isEmpty)
    }

    func testGroupedModelsUnknownProviderUsesID() {
        let models: [(providerID: String, modelID: String, name: String)] = [
            ("unknown", "m1", "Model"),
        ]
        let providers: [ProviderInfo] = []
        let groups = groupedModels(models, providers: providers)
        XCTAssertEqual(groups[0].providerName, "unknown")
    }

    // MARK: - PermissionStore

    private func makeTestStore(serverURL: String = "http://localhost:4096") -> PermissionStore {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return PermissionStore(serverURL: serverURL, defaults: defaults)
    }

    func testPermissionStoreLoadReturnsEmptySetForNonExistentKey() {
        let store = makeTestStore()
        XCTAssertTrue(store.loadPermissions().isEmpty)
    }

    func testPermissionStoreSaveLoadRoundtrip() {
        let store = makeTestStore()
        let ids: Set<String> = ["perm-1", "perm-2", "perm-3"]
        store.savePermissions(ids)
        let loaded = store.loadPermissions()
        XCTAssertEqual(loaded, ids)
    }

    func testPermissionStorePerServerIsolation() {
        let store1 = makeTestStore(serverURL: "http://server1:4096")
        let store2 = makeTestStore(serverURL: "http://server2:4096")

        store1.savePermissions(["perm-1"])
        store2.savePermissions(["perm-2"])

        XCTAssertEqual(store1.loadPermissions(), ["perm-1"])
        XCTAssertEqual(store2.loadPermissions(), ["perm-2"])
    }

    func testPermissionStoreClearRemovesAllData() {
        let store = makeTestStore()
        store.savePermissions(["p1"])
        store.saveQuestions(["q1"])
        store.saveDismissedPermissions(["dp1"])
        store.saveDismissedQuestions(["dq1"])
        store.clear()
        XCTAssertTrue(store.loadPermissions().isEmpty)
        XCTAssertTrue(store.loadQuestions().isEmpty)
        XCTAssertTrue(store.loadDismissedPermissions().isEmpty)
        XCTAssertTrue(store.loadDismissedQuestions().isEmpty)
    }

    func testPermissionStoreLastClearedTimestamp() {
        let store = makeTestStore()
        XCTAssertNil(store.loadLastCleared())
        store.clear()
        XCTAssertNotNil(store.loadLastCleared())
        let before = Date().addingTimeInterval(-1)
        let after = Date().addingTimeInterval(1)
        if let lastCleared = store.loadLastCleared() {
            XCTAssertGreaterThan(lastCleared, before)
            XCTAssertLessThan(lastCleared, after)
        }
    }
}

private func decodeTestMsg(id: String, text: String) throws -> MessageEnvelope {
    let json = """
    {"info": {"id": "\(id)", "role": "user", "time": {"created": 1000}}, "parts": [{"type": "text", "text": "\(text)"}]}
    """
    return try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
}
