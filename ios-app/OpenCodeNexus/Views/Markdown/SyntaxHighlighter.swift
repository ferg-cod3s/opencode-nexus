import SwiftUI

struct LanguageDef {
    let keywords: Set<String>
    let types: Set<String>
    let lineComment: String?
    let blockCommentStart: String?
    let blockCommentEnd: String?
    let stringDelimiters: [String]

    static let definitions: [String: LanguageDef] = [
        "swift": LanguageDef(
            keywords: ["import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let", "if", "else", "switch", "case", "default", "for", "in", "while", "return", "guard", "break", "continue", "throw", "try", "catch", "do", "self", "super", "init", "deinit", "typealias", "associatedtype", "public", "private", "internal", "fileprivate", "open", "static", "override", "mutating", "async", "await", "some", "any", "where", "as", "is", "nil", "true", "false", "required", "convenience", "lazy", "weak", "unowned", "inout", "infix", "prefix", "postfix", "operator", "subscript", "get", "set", "willSet", "didSet", "throws", "rethrows", "indirect", "nonisolated", "isolated", "sendable", "actor", "package"],
            types: ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "URL", "Date", "Data", "UUID", "Result", "Optional", "Any", "Void", "Never", "Error", "Codable", "Encodable", "Decodable", "Hashable", "Equatable", "Comparable", "Identifiable", "Observable", "Sendable", "View", "Color", "Image", "Text", "VStack", "HStack", "ZStack", "List", "NavigationStack", "NavigationSplitView", "ScrollView", "Button", "TextField", "Spacer", "Group", "ForEach", "Section", "State", "Binding", "MainActor", "Task"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            stringDelimiters: ["\""]
        ),
        "python": LanguageDef(
            keywords: ["import", "from", "class", "def", "if", "elif", "else", "for", "while", "return", "try", "except", "finally", "with", "as", "lambda", "yield", "pass", "break", "continue", "raise", "and", "or", "not", "in", "is", "None", "True", "False", "async", "await", "global", "nonlocal", "assert", "del"],
            types: ["str", "int", "float", "bool", "list", "dict", "set", "tuple", "bytes", "range", "type", "object", "Any", "Optional", "Union", "List", "Dict", "Set", "Tuple", "Callable"],
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            stringDelimiters: ["\"\"\"", "\"", "'"]
        ),
        "javascript": LanguageDef(
            keywords: ["import", "export", "from", "const", "let", "var", "function", "class", "if", "else", "switch", "case", "default", "for", "while", "do", "return", "break", "continue", "try", "catch", "finally", "throw", "new", "this", "super", "typeof", "instanceof", "in", "of", "async", "await", "yield", "void", "delete", "extends", "static", "get", "set"],
            types: ["string", "number", "boolean", "undefined", "null", "Promise", "Map", "Set", "Date", "RegExp", "Error", "Array", "Object", "console"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            stringDelimiters: ["\"", "'", "`"]
        ),
        "typescript": LanguageDef(
            keywords: ["import", "export", "from", "const", "let", "var", "function", "class", "interface", "type", "enum", "if", "else", "switch", "case", "default", "for", "while", "do", "return", "break", "continue", "try", "catch", "finally", "throw", "new", "this", "typeof", "instanceof", "in", "of", "async", "await", "extends", "implements", "static", "abstract", "as", "is", "keyof", "readonly", "private", "protected", "public", "declare", "module", "namespace"],
            types: ["string", "number", "boolean", "undefined", "null", "any", "never", "unknown", "void", "Promise", "Record", "Partial", "Required", "Readonly", "Pick", "Omit", "Array", "React", "ReactNode", "JSX", "Element"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            stringDelimiters: ["\"", "'", "`"]
        ),
        "go": LanguageDef(
            keywords: ["package", "import", "func", "var", "const", "type", "struct", "interface", "map", "chan", "if", "else", "switch", "case", "default", "for", "range", "return", "break", "continue", "go", "defer", "select", "fallthrough", "goto"],
            types: ["string", "int", "int8", "int16", "int32", "int64", "uint", "float32", "float64", "bool", "byte", "rune", "error", "any", "nil", "true", "false", "make", "new", "len", "cap", "append"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            stringDelimiters: ["\"", "`"]
        ),
        "rust": LanguageDef(
            keywords: ["use", "mod", "pub", "fn", "let", "mut", "const", "static", "struct", "enum", "impl", "trait", "type", "where", "if", "else", "match", "loop", "while", "for", "in", "return", "break", "continue", "as", "ref", "move", "self", "super", "crate", "async", "await", "dyn", "unsafe", "extern", "true", "false"],
            types: ["i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "f32", "f64", "bool", "char", "str", "String", "Vec", "Box", "Option", "Result", "Some", "None", "Ok", "Err", "HashMap", "HashSet"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            stringDelimiters: ["\""]
        ),
        "bash": LanguageDef(
            keywords: ["if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "function", "return", "exit", "break", "continue", "in", "select", "local", "declare", "export", "readonly", "source", "alias", "echo", "printf", "read", "cd", "pwd", "ls", "mkdir", "rm", "cp", "mv", "cat", "grep", "sed", "awk", "find", "sort", "head", "tail", "wc", "xargs", "chmod", "sudo", "git", "docker", "curl", "wget", "npm", "bun"],
            types: ["true", "false"],
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            stringDelimiters: ["\"", "'"]
        ),
        "shell": LanguageDef(
            keywords: ["if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "function", "return", "exit", "break", "continue", "in", "local", "export", "source", "echo", "printf"],
            types: ["true", "false"],
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            stringDelimiters: ["\"", "'"]
        ),
        "sh": LanguageDef(keywords: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "exit", "break", "continue", "in", "local", "export", "echo"], types: ["true", "false"], lineComment: "#", blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: ["\"", "'"]),
        "zsh": LanguageDef(keywords: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "exit", "break", "continue", "in", "local", "export", "source", "echo"], types: ["true", "false"], lineComment: "#", blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: ["\"", "'"]),
        "json": LanguageDef(keywords: [], types: ["true", "false", "null"], lineComment: nil, blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: ["\""]),
        "yaml": LanguageDef(keywords: ["true", "false", "null", "yes", "no"], types: [], lineComment: "#", blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: ["\"", "'"]),
        "html": LanguageDef(keywords: ["html", "head", "body", "div", "span", "p", "a", "img", "ul", "ol", "li", "h1", "h2", "h3", "form", "input", "button", "script", "style", "link", "meta", "title", "header", "footer", "nav", "main", "section", "article"], types: ["class", "id", "href", "src", "type", "value", "name", "style", "action", "method"], lineComment: nil, blockCommentStart: "<!--", blockCommentEnd: "-->", stringDelimiters: ["\"", "'"]),
        "css": LanguageDef(keywords: ["@media", "@keyframes", "@import", "!important", "from", "to"], types: ["inherit", "initial", "auto", "none", "block", "inline", "flex", "grid", "absolute", "relative", "solid", "dashed", "transparent"], lineComment: "//", blockCommentStart: "/*", blockCommentEnd: "*/", stringDelimiters: ["\"", "'"]),
        "sql": LanguageDef(keywords: ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "JOIN", "INNER", "LEFT", "RIGHT", "ON", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "AS", "DISTINCT", "COUNT", "SUM", "AVG", "MIN", "MAX", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END", "PRIMARY", "KEY", "NULL", "IS"], types: ["INTEGER", "TEXT", "VARCHAR", "BOOLEAN", "FLOAT", "DATE", "TIMESTAMP", "SERIAL", "BIGINT", "CHAR", "UUID"], lineComment: "--", blockCommentStart: "/*", blockCommentEnd: "*/", stringDelimiters: ["\"", "'"]),
        "diff": LanguageDef(keywords: [], types: [], lineComment: nil, blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: []),
        "markdown": LanguageDef(keywords: [], types: [], lineComment: nil, blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: []),
    ]

    static func languageDef(for language: String?) -> LanguageDef? {
        guard let language else { return nil }
        return definitions[language.lowercased()]
    }
}

struct SyntaxHighlighter {
    static func highlight(_ source: String, language: String?) -> AttributedString {
        guard let langDef = LanguageDef.languageDef(for: language) else {
            return AttributedString(source)
        }

        if language?.lowercased() == "diff" {
            return highlightDiff(source)
        }

        let nsSource = source as NSString
        let commentRanges = findCommentRanges(in: nsSource, def: langDef)
        let stringRanges = findStringRanges(in: nsSource, def: langDef)
        let excluded = commentRanges + stringRanges

        var tokens: [(range: NSRange, color: ThemeColor)] = []

        for range in commentRanges {
            tokens.append((range, .comment))
        }
        for range in stringRanges {
            tokens.append((range, .string))
        }

        let wordPattern = #"\b[a-zA-Z_]\w*\b"#
        if let regex = try? NSRegularExpression(pattern: wordPattern) {
            let fullRange = nsSource.range(of: source)
            for match in regex.matches(in: source, options: [], range: fullRange) {
                guard !isExcluded(match.range, in: excluded) else { continue }
                let word = nsSource.substring(with: match.range)
                if langDef.keywords.contains(word) {
                    tokens.append((match.range, .keyword))
                } else if langDef.types.contains(word) {
                    tokens.append((match.range, .type))
                }
            }
        }

        let numberPattern = #"\b\d+\.?\d*\b"#
        if let regex = try? NSRegularExpression(pattern: numberPattern) {
            let fullRange = nsSource.range(of: source)
            for match in regex.matches(in: source, options: [], range: fullRange) {
                guard !isExcluded(match.range, in: excluded) else { continue }
                tokens.append((match.range, .number))
            }
        }

        tokens.sort { $0.range.location < $1.range.location }

        return buildAttributedString(from: source, tokens: tokens)
    }

    private enum ThemeColor {
        case keyword, string, comment, number, type
        var color: Color {
            switch self {
            case .keyword: Theme.tokenKeyword
            case .string: Theme.tokenString
            case .comment: Theme.tokenComment
            case .number: Theme.tokenNumber
            case .type: Theme.tokenType
            }
        }
    }

    private static func buildAttributedString(from source: String, tokens: [(range: NSRange, color: ThemeColor)]) -> AttributedString {
        let nsSource = source as NSString
        var result = ""
        var colorMap: [(start: String.Index, end: String.Index, color: Color)] = []

        var lastEnd = 0
        for token in tokens {
            if token.range.location > lastEnd {
                let plain = nsSource.substring(with: NSRange(location: lastEnd, length: token.range.location - lastEnd))
                result += plain
            }
            let tokenStart = result.endIndex
            let tokenText = nsSource.substring(with: token.range)
            result += tokenText
            colorMap.append((tokenStart, result.endIndex, token.color.color))
            lastEnd = token.range.location + token.range.length
        }

        if lastEnd < nsSource.length {
            result += nsSource.substring(from: lastEnd)
        }

        var attributed = AttributedString(result)
        for entry in colorMap {
            if let lower = AttributedString.Index(entry.start, within: attributed),
               let upper = AttributedString.Index(entry.end, within: attributed) {
                attributed[lower..<upper].foregroundColor = entry.color
            }
        }

        return attributed
    }

    private static func highlightDiff(_ source: String) -> AttributedString {
        let nsSource = source as NSString
        var tokens: [(range: NSRange, color: ThemeColor)] = []
        var location = 0

        for line in source.components(separatedBy: "\n") {
            let lineLength = (nsSource.length > location) ? nsSource.substring(with: NSRange(location: location, length: min(line.utf16.count, nsSource.length - location))).utf16.count : 0
            let lineRange = NSRange(location: location, length: lineLength)
            if let firstChar = line.first {
                switch firstChar {
                case "+":
                    tokens.append((lineRange, .string))
                case "-":
                    tokens.append((lineRange, .keyword))
                case "@":
                    tokens.append((lineRange, .type))
                default:
                    break
                }
            }
            location += lineLength + 1
        }

        return buildAttributedString(from: source, tokens: tokens)
    }

    private static func findCommentRanges(in nsSource: NSString, def: LanguageDef) -> [NSRange] {
        var ranges: [NSRange] = []
        let fullRange = NSRange(location: 0, length: nsSource.length)

        if let lineComment = def.lineComment {
            let escaped = NSRegularExpression.escapedPattern(for: lineComment)
            let pattern = "\(escaped)[^\\n]*"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                ranges.append(contentsOf: regex.matches(in: nsSource as String, options: [], range: fullRange).map(\.range))
            }
        }

        if let start = def.blockCommentStart, let end = def.blockCommentEnd {
            let escapedStart = NSRegularExpression.escapedPattern(for: start)
            let escapedEnd = NSRegularExpression.escapedPattern(for: end)
            let pattern = "\(escapedStart)[\\s\\S]*?\(escapedEnd)"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                ranges.append(contentsOf: regex.matches(in: nsSource as String, options: [], range: fullRange).map(\.range))
            }
        }

        return ranges
    }

    private static func findStringRanges(in nsSource: NSString, def: LanguageDef) -> [NSRange] {
        var ranges: [NSRange] = []
        let fullRange = NSRange(location: 0, length: nsSource.length)

        let sortedDelimiters = def.stringDelimiters.sorted { $0.count > $1.count }
        for delimiter in sortedDelimiters {
            let escaped = NSRegularExpression.escapedPattern(for: delimiter)
            let pattern = "\(escaped)(?:[^\\n\\\\]|\\\\.)*?\(escaped)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            ranges.append(contentsOf: regex.matches(in: nsSource as String, options: [], range: fullRange).map(\.range))
        }

        return ranges
    }

    private static func isExcluded(_ range: NSRange, in excluded: [NSRange]) -> Bool {
        excluded.contains { NSIntersectionRange(range, $0).length > 0 }
    }
}
