import XCTest
import Synchronization
@testable import OpenCodeNexus

final class FileBrowserViewModelTests: XCTestCase {

    private var client: OpenCodeClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!, configuration: config)
        MockURLProtocol.setRequestHandler(nil)
    }

    override func tearDown() {
        MockURLProtocol.setRequestHandler(nil)
        client = nil
        super.tearDown()
    }

    @MainActor
    func testLoadFiles() async throws {
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/file" {
                let json = """
                [
                    {"name": "src", "path": "src", "absolute": "/project/src", "type": "directory", "ignored": false},
                    {"name": "Package.swift", "path": "Package.swift", "absolute": "/project/Package.swift", "type": "file", "ignored": false}
                ]
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        json.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        await vm.loadFiles()
        XCTAssertEqual(vm.files.count, 2)
        XCTAssertTrue(vm.files[0].isDirectory || vm.files[1].isDirectory)
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testLoadFilesAtPath() async throws {
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/file" {
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "path" })?.value, "src")
                let json = """
                [{"name": "main.swift", "path": "src/main.swift", "absolute": "/project/src/main.swift", "type": "file", "ignored": false}]
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        json.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        await vm.loadFiles(path: "src")
        XCTAssertEqual(vm.files.count, 1)
        XCTAssertEqual(vm.files[0].name, "main.swift")
        XCTAssertEqual(vm.currentPath, "src")
    }

    @MainActor
    func testNavigateIntoDirectory() async throws {
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/file" {
                let json = """
                [{"name": "src", "path": "src", "absolute": "/project/src", "type": "directory", "ignored": false}]
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        json.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        await vm.loadFiles()
        let dir = FileNode(name: "src", path: "src", absolute: "/project/src", type: "directory", ignored: false)
        await vm.navigateInto(dir)
        XCTAssertEqual(vm.navigationStack.count, 1)
        XCTAssertEqual(vm.currentPath, "src")
    }

    @MainActor
    func testNavigateBack() async throws {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        let dir = FileNode(name: "src", path: "src", absolute: "/project/src", type: "directory", ignored: false)
        vm.navigationStack = [dir]
        await vm.navigateBack()
        XCTAssertEqual(vm.navigationStack.count, 0)
    }

    @MainActor
    func testSearchFindsFiles() async throws {
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/find/file" {
                let json = """
                ["src/main.swift", "src/utils.swift"]
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        json.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        vm.searchText = "swift"
        vm.search()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(vm.matchedFiles.count, 2)
    }

    @MainActor
    func testSearchFindsText() async throws {
        MockURLProtocol.setRequestHandler { request in
            if request.url?.path == "/find" {
                let json = """
                [{"path": "src/main.swift", "line": 42, "text": "print(\\"hello\\")"}]
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        json.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        vm.searchText = "print"
        vm.search()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(vm.searchResults.count, 1)
        XCTAssertEqual(vm.searchResults[0].line, 42)
    }

    @MainActor
    func testSearchIncludesDirectoryForFindEndpoints() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            if components.path == "/find/file" {
                XCTAssertEqual(query["directory"], "/workspace/app")
                XCTAssertEqual(query["query"], "swift")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
            }
            if components.path == "/find" {
                XCTAssertEqual(query["directory"], "/workspace/app")
                XCTAssertEqual(query["pattern"], "swift")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
            }
            XCTFail("Unexpected path: \(components.path)")
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        let vm = FileBrowserViewModel(client: client, directory: "/workspace/app")
        vm.searchText = "swift"
        vm.search()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertFalse(vm.isSearching)
    }

    @MainActor
    func testSearchClearsOnEmpty() {
        let vm = FileBrowserViewModel(client: client, directory: nil)
        vm.matchedFiles = ["test.swift"]
        vm.searchResults = [SearchResult(path: "test.swift", line: 1, text: "hello")]
        vm.isSearching = true
        vm.searchText = ""
        vm.search()
        XCTAssertEqual(vm.matchedFiles.count, 0)
        XCTAssertEqual(vm.searchResults.count, 0)
        XCTAssertFalse(vm.isSearching)
    }

    @MainActor
    func testDisplayFilesSortsDirectoriesFirst() {
        let vm = FileBrowserViewModel(client: client, directory: nil)
        vm.files = [
            FileNode(name: "b.swift", path: "b.swift", absolute: "/b.swift", type: "file", ignored: false),
            FileNode(name: "a", path: "a", absolute: "/a", type: "directory", ignored: false),
            FileNode(name: "a.swift", path: "a.swift", absolute: "/a.swift", type: "file", ignored: false)
        ]
        let display = vm.displayFiles
        XCTAssertEqual(display[0].name, "a")
        XCTAssertTrue(display[0].isDirectory)
        XCTAssertEqual(display[1].name, "a.swift")
        XCTAssertEqual(display[2].name, "b.swift")
    }

    @MainActor
    func testDisplayFilesIsEmptyWhenCompletedSearchHasNoFilenameMatches() async throws {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        vm.files = [
            FileNode(name: "main.swift", path: "src/main.swift", absolute: "/project/src/main.swift", type: "file", ignored: false)
        ]
        vm.searchText = "missing"
        vm.search()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(vm.displayFiles.isEmpty)
    }

    @MainActor
    func testDisplayFilesIncludesNestedMatchedFileMissingFromCurrentDirectoryListing() {
        let vm = FileBrowserViewModel(client: client, directory: "/project")
        vm.files = [
            FileNode(name: "src", path: "src", absolute: "/project/src", type: "directory", ignored: false)
        ]
        vm.searchText = "main"
        vm.matchedFiles = ["src/nested/main.swift"]

        let display = vm.displayFiles

        XCTAssertEqual(display.count, 1)
        XCTAssertEqual(display[0].name, "main.swift")
        XCTAssertEqual(display[0].path, "src/nested/main.swift")
        XCTAssertEqual(display[0].absolute, "/project/src/nested/main.swift")
        XCTAssertFalse(display[0].isDirectory)
        XCTAssertFalse(display[0].ignored)
    }

    @MainActor
    func testStatusMap() {
        let vm = FileBrowserViewModel(client: client, directory: nil)
        vm.fileStatuses = [
            FileStatus(path: "src/main.swift", added: 5, removed: 2, status: "modified")
        ]
        let map = vm.statusMap
        XCTAssertEqual(map["src/main.swift"]?.added, 5)
        XCTAssertEqual(map["src/main.swift"]?.removed, 2)
    }

    @MainActor
    func testLoadFilesErrorHandling() async throws {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                    "error".data(using: .utf8)!)
        }
        let vm = FileBrowserViewModel(client: client, directory: nil)
        await vm.loadFiles()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }
}
