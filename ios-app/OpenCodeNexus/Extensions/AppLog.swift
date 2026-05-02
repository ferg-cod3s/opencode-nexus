import Foundation
import os
import Sentry

/// Lightweight logging facade that fans every call out to:
/// 1. `os.Logger` (visible in Console.app / `log stream`)
/// 2. `FileLogger` (rotating local file — survives crash, no network needed)
/// 3. `SentrySDK` breadcrumbs / events (when DSN is configured)
///
/// Usage:
/// ```swift
/// private let log = AppLog(category: "ChatViewModel")
/// log.info("Stream connected")
/// log.error("Send failed", error: error)
/// ```
struct AppLog: Sendable {
    private let osLogger: Logger
    private let category: String

    init(category: String, subsystem: String = "ai.v1truv1us.opencode-mobile") {
        self.osLogger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    func debug(_ message: @autoclosure () -> String) {
        let m = message()
        osLogger.debug("\(m, privacy: .public)")
        FileLogger.shared.log(.debug, category: category, m)
        // Don't send debug-level breadcrumbs to Sentry — too noisy.
    }

    func info(_ message: @autoclosure () -> String) {
        let m = message()
        osLogger.info("\(m, privacy: .public)")
        FileLogger.shared.log(.info, category: category, m)
        // Verbose mode: every info call becomes a Sentry event. Off: breadcrumb only.
        if CrashReporter.verboseEventsEnabled {
            CrashReporter.capture(message: m, level: .info, category: category)
        } else {
            CrashReporter.breadcrumb(category: category, message: m, level: .info)
        }
    }

    func warning(_ message: @autoclosure () -> String) {
        let m = message()
        osLogger.warning("\(m, privacy: .public)")
        FileLogger.shared.log(.warning, category: category, m)
        if CrashReporter.verboseEventsEnabled {
            CrashReporter.capture(message: m, level: .warning, category: category)
        } else {
            CrashReporter.breadcrumb(category: category, message: m, level: .warning)
        }
    }

    /// Logs an error and (if Sentry is enabled) captures it as an event so
    /// it shows up in the Sentry Issues stream — not just as breadcrumb context.
    func error(_ message: @autoclosure () -> String, error: Error? = nil) {
        let m = message()
        if let error {
            osLogger.error("\(m, privacy: .public): \(String(describing: error), privacy: .public)")
            FileLogger.shared.log(.error, category: category, "\(m): \(error)")
            CrashReporter.capture(error: error, category: category)
        } else {
            osLogger.error("\(m, privacy: .public)")
            FileLogger.shared.log(.error, category: category, m)
            CrashReporter.capture(message: m, level: .error, category: category)
        }
    }

    /// For unrecoverable conditions. Always sends to Sentry as a fatal-level event.
    func fault(_ message: @autoclosure () -> String) {
        let m = message()
        osLogger.fault("\(m, privacy: .public)")
        FileLogger.shared.log(.fault, category: category, m)
        CrashReporter.capture(message: m, level: .fatal, category: category)
    }
}
