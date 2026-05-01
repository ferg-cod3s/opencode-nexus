import SwiftUI

struct BashToolView: View {
    let input: [String: JSONValue]?
    let output: String?

    private var command: String {
        input?["command"]?.stringValue ?? ""
    }

    private var workdir: String? {
        input?["workdir"]?.stringValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(Theme.interactiveBlue)
                Text(workdir != nil ? "\(workdir ?? "") $" : "$")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textWeak)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textStrong)
                    .textSelection(.enabled)
            }
            if let output, !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textBase)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

struct FileReadToolView: View {
    let input: [String: JSONValue]?
    let output: String?

    private var filePath: String {
        input?["filePath"]?.stringValue ?? input?["path"]?.stringValue ?? ""
    }

    private var offset: Int? {
        input?["offset"]?.intValue
    }

    private var limit: Int? {
        input?["limit"]?.intValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(Theme.brandYuzu)
                Text(filePath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textStrong)
                    .textSelection(.enabled)
                Spacer()
                if let offset, let limit {
                    Text("L\(offset)–\(offset + limit)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textWeak)
                } else if let offset {
                    Text("L\(offset)–")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textWeak)
                }
            }
            if let output, !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textBase)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct FileEditToolView: View {
    let input: [String: JSONValue]?

    private var filePath: String {
        input?["filePath"]?.stringValue ?? ""
    }

    private var oldString: String {
        input?["oldString"]?.stringValue ?? ""
    }

    private var newString: String {
        input?["newString"]?.stringValue ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.line")
                    .font(.caption)
                    .foregroundStyle(Theme.success)
                Text(filePath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textStrong)
                    .textSelection(.enabled)
                Spacer()
                Text(oldString.isEmpty ? "Create" : "Edit")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(oldString.isEmpty ? Theme.success : Theme.interactiveBlue)
            }
            if !oldString.isEmpty {
                diffPreview
            }
        }
    }

    private var diffPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !oldString.isEmpty {
                HStack(spacing: 4) {
                    Text("-")
                        .foregroundStyle(Theme.errorCritical)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(oldString.prefix(200))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.errorCritical.opacity(0.8))
                    }
                }
            }
            if !newString.isEmpty {
                HStack(spacing: 4) {
                    Text("+")
                        .foregroundStyle(Theme.success)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(newString.prefix(200))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.success.opacity(0.8))
                    }
                }
            }
        }
        .padding(.leading, 8)
    }
}

struct SearchToolView: View {
    let input: [String: JSONValue]?
    let output: String?
    let icon: String
    let color: Color

    private var pattern: String {
        input?["pattern"]?.stringValue ?? input?["query"]?.stringValue ?? ""
    }

    private var include: String? {
        input?["include"]?.stringValue
    }

    private var path: String? {
        input?["path"]?.stringValue ?? input?["directory"]?.stringValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(pattern)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textStrong)
                    .textSelection(.enabled)
                Spacer()
                if let include {
                    Text(include)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textWeak)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceRaised.opacity(0.5), in: Capsule())
                }
            }
            if let path {
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textWeak)
            }
            if let output, !output.isEmpty {
                let results = parseResults(output)
                if results.count > 0 {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(results.prefix(20).enumerated()), id: \.offset) { _, result in
                                SearchResultRow(result: result)
                            }
                            if results.count > 20 {
                                Text("+ \(results.count - 20) more")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Theme.textWeak)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }

    func parseResults(_ output: String) -> [ToolSearchResult] {
        output.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let parts = trimmed.split(separator: ":", maxSplits: 2).map(String.init)
            if parts.count >= 2 {
                return ToolSearchResult(
                    file: parts[0],
                    line: parts.count > 1 ? parts[1] : nil,
                    text: parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : nil
                )
            }
            return ToolSearchResult(file: trimmed, line: nil, text: nil)
        }
    }
}

struct ToolSearchResult {
    let file: String
    let line: String?
    let text: String?
}

struct SearchResultRow: View {
    let result: ToolSearchResult

    var body: some View {
        HStack(spacing: 6) {
            Text(result.file)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textStrong)
                .lineLimit(1)
            if let line = result.line {
                Text(":\(line)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textWeak)
            }
            if let text = result.text {
                Text(text.prefix(80))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textBase)
                    .lineLimit(1)
            }
        }
    }
}

struct WriteToolView: View {
    let input: [String: JSONValue]?

    private var filePath: String {
        input?["filePath"]?.stringValue ?? ""
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.caption)
                .foregroundStyle(Theme.success)
            Text(filePath)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textStrong)
                .textSelection(.enabled)
        }
    }
}

struct WebFetchToolView: View {
    let input: [String: JSONValue]?
    let output: String?

    private var url: String {
        input?["url"]?.stringValue ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(Theme.interactiveBlue)
                Text(url)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.interactiveBlue)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
            if let output, !output.isEmpty {
                ScrollView {
                    Text(output.prefix(500))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textBase)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

struct SubagentToolView: View {
    let input: [String: JSONValue]?
    let output: String?

    private var prompt: String {
        input?["prompt"]?.stringValue ?? input?["task"]?.stringValue ?? ""
    }

    private var subagentType: String {
        input?["subagent_type"]?.stringValue ?? input?["description"]?.stringValue ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.wave.2")
                    .font(.caption)
                    .foregroundStyle(Theme.brandYuzu)
                if !subagentType.isEmpty {
                    Text(subagentType)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textWeak)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceRaised.opacity(0.5), in: Capsule())
                }
            }
            if !prompt.isEmpty {
                Text(prompt.prefix(200))
                    .font(.system(.caption2))
                    .foregroundStyle(Theme.textBase)
                    .lineLimit(3)
            }
        }
    }
}
