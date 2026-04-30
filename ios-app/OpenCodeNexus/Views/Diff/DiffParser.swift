import Foundation

enum DiffLineType {
    case context, addition, deletion, header, noNewline
}

struct DiffLine: Identifiable {
    let id: Int
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

struct DiffParser {
    static func parse(_ content: String) -> [DiffLine] {
        var lines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0
        var index = 0

        for raw in content.components(separatedBy: "\n") {
            guard !raw.isEmpty else { continue }

            if raw.hasPrefix("@@") {
                let pattern = /@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/
                if let match = raw.firstMatch(of: pattern) {
                    oldLine = Int(match.output.1) ?? 0
                    newLine = Int(match.output.2) ?? 0
                }
                lines.append(DiffLine(id: index, type: .header, content: raw, oldLineNumber: nil, newLineNumber: nil))
                index += 1
                continue
            }

            if raw.hasPrefix("\\ No newline") {
                lines.append(DiffLine(id: index, type: .noNewline, content: raw, oldLineNumber: nil, newLineNumber: nil))
                index += 1
                continue
            }

            let contentChar = raw.first.map(String.init) ?? ""

            if contentChar == "+" {
                lines.append(DiffLine(id: index, type: .addition, content: String(raw.dropFirst()), oldLineNumber: nil, newLineNumber: newLine))
                newLine += 1
            } else if contentChar == "-" {
                lines.append(DiffLine(id: index, type: .deletion, content: String(raw.dropFirst()), oldLineNumber: oldLine, newLineNumber: nil))
                oldLine += 1
            } else {
                lines.append(DiffLine(id: index, type: .context, content: String(raw.dropFirst()), oldLineNumber: oldLine, newLineNumber: newLine))
                oldLine += 1
                newLine += 1
            }
            index += 1
        }

        return lines
    }

    static func parseHunks(_ hunks: [FilePatchHunk]) -> [DiffLine] {
        var lines: [DiffLine] = []
        var index = 0

        for hunk in hunks {
            lines.append(DiffLine(id: index, type: .header, content: "@@ -\(hunk.oldStart),\(hunk.oldLines) +\(hunk.newStart),\(hunk.newLines) @@", oldLineNumber: nil, newLineNumber: nil))
            index += 1

            var oldLine = hunk.oldStart
            var newLine = hunk.newStart

            for line in hunk.lines {
                if line.hasPrefix("+") {
                    lines.append(DiffLine(id: index, type: .addition, content: String(line.dropFirst()), oldLineNumber: nil, newLineNumber: newLine))
                    newLine += 1
                } else if line.hasPrefix("-") {
                    lines.append(DiffLine(id: index, type: .deletion, content: String(line.dropFirst()), oldLineNumber: oldLine, newLineNumber: nil))
                    oldLine += 1
                } else if line.hasPrefix("\\") {
                    lines.append(DiffLine(id: index, type: .noNewline, content: line, oldLineNumber: nil, newLineNumber: nil))
                } else {
                    lines.append(DiffLine(id: index, type: .context, content: String(line.dropFirst()), oldLineNumber: oldLine, newLineNumber: newLine))
                    oldLine += 1
                    newLine += 1
                }
                index += 1
            }
        }

        return lines
    }
}
