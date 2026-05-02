import Foundation
import os

/// Writes structured log lines to a rotating file in Application Support.
/// Used as an always-on fallback so we have crash context even when Sentry
/// is unconfigured or the device is offline.
final class FileLogger: @unchecked Sendable {
    static let shared = FileLogger()

    enum Level: String { case debug, info, warning, error, fault }

    private let queue = DispatchQueue(label: "ai.v1truv1us.opencode-mobile.filelogger", qos: .utility)
    private let directory: URL
    private let currentURL: URL
    private let maxBytes: UInt64 = 5 * 1024 * 1024 // 5 MB per file
    private let maxGenerations = 3
    private let isoFormatter: ISO8601DateFormatter
    private var handle: FileHandle?

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true))
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Logs", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.directory = dir
        self.currentURL = dir.appendingPathComponent("opencode-nexus.log")

        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = f

        ensureFileExists()
        openHandle()
    }

    // MARK: - Public API

    func log(_ level: Level, category: String, _ message: String) {
        let line = formatLine(level: level, category: category, message: message)
        queue.async { [weak self] in
            self?.writeLine(line)
        }
    }

    /// All log files in the rotation, newest first. Used by the in-app viewer.
    func currentLogFiles() -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries
            .filter { $0.pathExtension == "log" || $0.lastPathComponent.contains(".log") }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
    }

    /// Concatenated tail of the current log, capped at `maxBytes` for display.
    func currentLogContents(maxBytes: Int = 256 * 1024) -> String {
        queue.sync { flushHandle() }
        guard let data = try? Data(contentsOf: currentURL) else { return "" }
        let slice = data.suffix(maxBytes)
        return String(data: slice, encoding: .utf8) ?? ""
    }

    // MARK: - Internals

    private func formatLine(level: Level, category: String, message: String) -> String {
        let timestamp = isoFormatter.string(from: Date())
        // Single line so log lines are grep-friendly. Newlines in message are escaped.
        let safeMessage = message.replacingOccurrences(of: "\n", with: "\\n")
        return "\(timestamp) [\(level.rawValue.uppercased())] \(category): \(safeMessage)\n"
    }

    private func ensureFileExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: currentURL.path) {
            fm.createFile(atPath: currentURL.path, contents: nil)
        }
    }

    private func openHandle() {
        handle = try? FileHandle(forWritingTo: currentURL)
        _ = try? handle?.seekToEnd()
    }

    private func writeLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        rotateIfNeeded(addingBytes: UInt64(data.count))
        if handle == nil { openHandle() }
        do {
            try handle?.write(contentsOf: data)
        } catch {
            // Last-ditch: try to recover by reopening once.
            try? handle?.close()
            handle = nil
            openHandle()
            try? handle?.write(contentsOf: data)
        }
    }

    private func flushHandle() {
        try? handle?.synchronize()
    }

    private func rotateIfNeeded(addingBytes: UInt64) {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: currentURL.path)
        let size = (attrs?[.size] as? UInt64) ?? 0
        guard size + addingBytes > maxBytes else { return }

        try? handle?.close()
        handle = nil

        // Shift opencode-nexus.log -> opencode-nexus.1.log -> ... drop oldest.
        for i in stride(from: maxGenerations - 1, through: 1, by: -1) {
            let src = directory.appendingPathComponent("opencode-nexus.\(i).log")
            let dst = directory.appendingPathComponent("opencode-nexus.\(i + 1).log")
            if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
            if fm.fileExists(atPath: src.path) { try? fm.moveItem(at: src, to: dst) }
        }
        let firstRotated = directory.appendingPathComponent("opencode-nexus.1.log")
        if fm.fileExists(atPath: firstRotated.path) { try? fm.removeItem(at: firstRotated) }
        if fm.fileExists(atPath: currentURL.path) {
            try? fm.moveItem(at: currentURL, to: firstRotated)
        }
        ensureFileExists()
        openHandle()
    }
}
