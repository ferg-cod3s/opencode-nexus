import XCTest
@testable import OpenCodeNexus

final class MarkdownRendererTests: XCTestCase {

    func testRenderPlainTextOnly() {
        let segments = MarkdownRenderer.render("Hello world")
        XCTAssertEqual(segments.count, 1)
        if case .markdown = segments[0] {
        } else {
            XCTFail("Expected markdown segment")
        }
    }

    func testRenderCodeBlockWithLanguage() {
        let input = "```swift\nlet x = 1\n```"
        let segments = MarkdownRenderer.render(input)
        XCTAssertEqual(segments.count, 1)
        if case .codeBlock(let lang, let source) = segments[0] {
            XCTAssertEqual(lang, "swift")
            XCTAssertEqual(source, "let x = 1")
        } else {
            XCTFail("Expected codeBlock segment")
        }
    }

    func testRenderCodeBlockWithoutLanguage() {
        let input = "```\ncode\n```"
        let segments = MarkdownRenderer.render(input)
        XCTAssertEqual(segments.count, 1)
        if case .codeBlock(let lang, let source) = segments[0] {
            XCTAssertNil(lang)
            XCTAssertEqual(source, "code")
        } else {
            XCTFail("Expected codeBlock segment")
        }
    }

    func testRenderMixedMarkdownAndCode() {
        let input = "before\n```swift\ncode\n```\nafter"
        let segments = MarkdownRenderer.render(input)
        XCTAssertTrue(segments.count >= 2)
        let codeSegment = segments.first { if case .codeBlock = $0 { return true } else { return false } }
        XCTAssertNotNil(codeSegment)
    }

    func testRenderAdjacentCodeBlocks() {
        let input = "```swift\ncode1\n```\n```python\ncode2\n```"
        let segments = MarkdownRenderer.render(input)
        let codeBlocks = segments.filter { if case .codeBlock = $0 { return true } else { return false } }
        XCTAssertEqual(codeBlocks.count, 2)
    }

    func testRenderUnclosedCodeFence() {
        let input = "```swift\nno closing fence"
        let segments = MarkdownRenderer.render(input)
        XCTAssertTrue(segments.count >= 1)
    }

    func testRenderEmptyInput() {
        let segments = MarkdownRenderer.render("")
        XCTAssertTrue(segments.isEmpty)
    }

    func testRenderOnlyCodeBlock() {
        let input = "```\njust code\n```"
        let segments = MarkdownRenderer.render(input)
        XCTAssertEqual(segments.count, 1)
        if case .codeBlock(let lang, _) = segments[0] {
            XCTAssertNil(lang)
        } else {
            XCTFail("Expected codeBlock segment")
        }
    }

    func testRenderCodeBlockPreservesSourceContent() {
        let code = "  indented\n  {\"key\": \"value\"}\n  trailing"
        let input = "```json\n\(code)\n```"
        let segments = MarkdownRenderer.render(input)
        if case .codeBlock(_, let source) = segments.first {
            XCTAssertEqual(source, code)
        } else {
            XCTFail("Expected codeBlock segment")
        }
    }

    func testRenderTrailingMarkdown() {
        let input = "```swift\ncode\n```\nSome trailing text"
        let segments = MarkdownRenderer.render(input)
        XCTAssertTrue(segments.count >= 2)
    }

    func testRenderWhitespaceOnlyInput() {
        let segments = MarkdownRenderer.render("   \n\n  ")
        XCTAssertTrue(segments.isEmpty)
    }
}
