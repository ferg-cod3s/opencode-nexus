import XCTest
@testable import OpenCodeNexus

final class SyntaxHighlighterTests: XCTestCase {

    func testHighlightReturnsAttributedStringForNilLanguage() {
        let result = SyntaxHighlighter.highlight("let x = 1", language: nil)
        XCTAssertEqual(String(result.characters), "let x = 1")
    }

    func testHighlightReturnsAttributedStringForUnknownLanguage() {
        let result = SyntaxHighlighter.highlight("some code", language: "cobol")
        XCTAssertEqual(String(result.characters), "some code")
    }

    func testHighlightKeywordsInSwift() {
        let result = SyntaxHighlighter.highlight("import Foundation", language: "swift")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("import"))
    }

    func testHighlightTypesInSwift() {
        let result = SyntaxHighlighter.highlight("var x: String", language: "swift")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("String"))
    }

    func testHighlightLineCommentInSwift() {
        let result = SyntaxHighlighter.highlight("// this is a comment", language: "swift")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("// this is a comment"))
    }

    func testHighlightBlockCommentInSwift() {
        let result = SyntaxHighlighter.highlight("/* block */", language: "swift")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("/* block */"))
    }

    func testHighlightStringLiteralInSwift() {
        let result = SyntaxHighlighter.highlight("\"hello world\"", language: "swift")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("\"hello world\""))
    }

    func testHighlightNumbers() {
        let result = SyntaxHighlighter.highlight("42", language: "swift")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("42"))
    }

    func testHighlightDiffAddedLines() {
        let source = "+added line\n-context\n-removed"
        let result = SyntaxHighlighter.highlight(source, language: "diff")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("+added line"))
    }

    func testHighlightDiffHeaderLines() {
        let source = "@@ -1,3 +1,4 @@"
        let result = SyntaxHighlighter.highlight(source, language: "diff")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("@@ -1,3 +1,4 @@"))
    }

    func testLanguageDefReturnsDefinitionForSwift() {
        let def = LanguageDef.languageDef(for: "swift")
        XCTAssertNotNil(def)
        XCTAssertTrue(def!.keywords.contains("func"))
    }

    func testLanguageDefReturnsDefinitionForPython() {
        let def = LanguageDef.languageDef(for: "python")
        XCTAssertNotNil(def)
        XCTAssertTrue(def!.keywords.contains("def"))
    }

    func testLanguageDefReturnsNilForUnknown() {
        let def = LanguageDef.languageDef(for: "cobol")
        XCTAssertNil(def)
    }

    func testLanguageDefReturnsNilForNil() {
        let def = LanguageDef.languageDef(for: nil)
        XCTAssertNil(def)
    }

    func testLanguageDefIsCaseInsensitive() {
        XCTAssertNotNil(LanguageDef.languageDef(for: "Swift"))
        XCTAssertNotNil(LanguageDef.languageDef(for: "SWIFT"))
        XCTAssertNotNil(LanguageDef.languageDef(for: "Swift"))
    }

    func testHighlightEmptySource() {
        let result = SyntaxHighlighter.highlight("", language: "swift")
        XCTAssertTrue(String(result.characters).isEmpty)
    }

    func testHighlightPythonLineComment() {
        let result = SyntaxHighlighter.highlight("# comment", language: "python")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("# comment"))
    }

    func testHighlightJavaScriptKeywords() {
        let result = SyntaxHighlighter.highlight("const x = 1", language: "javascript")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("const"))
    }

    func testHighlightGoKeywords() {
        let result = SyntaxHighlighter.highlight("func main()", language: "go")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("func"))
    }

    func testHighlightSQLKeywords() {
        let result = SyntaxHighlighter.highlight("SELECT * FROM users", language: "sql")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("SELECT"))
    }

    func testHighlightBashKeywords() {
        let result = SyntaxHighlighter.highlight("if true; then echo hello; fi", language: "bash")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("if"))
    }

    func testHighlightRustKeywords() {
        let result = SyntaxHighlighter.highlight("fn main()", language: "rust")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("fn"))
    }

    func testHighlightTypeScriptKeywords() {
        let result = SyntaxHighlighter.highlight("interface Foo {}", language: "typescript")
        let str = String(result.characters)
        XCTAssertTrue(str.contains("interface"))
    }

    func testAllDefinedLanguages() {
        let langs = ["swift", "python", "javascript", "typescript", "go", "rust", "bash", "shell", "sh", "zsh", "json", "yaml", "html", "css", "sql", "diff", "markdown"]
        for lang in langs {
            XCTAssertNotNil(LanguageDef.languageDef(for: lang), "Missing language def for: \(lang)")
        }
    }
}
