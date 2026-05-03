import Foundation
import Sentry
import os

/// Single entry point for crash + error monitoring.
///
/// Behaviour:
/// - Reads `SentryDSN` from Info.plist. If empty, Sentry is **not** started
///   (no crash reports leave the device) but local file logging continues
///   so we always have an offline paper trail for TestFlight crash investigation.
/// - Bridges into `FileLogger` so every breadcrumb / captured event also
///   appears in the local rotating log.
enum CrashReporter {
    /// Snapshot of whether SentrySDK was actually started this launch.
    /// Written exactly once from `bootstrap()` during `App.init` (main thread,
    /// before any concurrent work) and read-only thereafter — safe under
    /// `nonisolated(unsafe)`.
    nonisolated(unsafe) private(set) static var isEnabled = false

    /// When true, AppLog.info / AppLog.warning emit Sentry events (max diagnostic).
    /// When false, those calls degrade to Sentry breadcrumbs only — the cheap mode
    /// once we've finished shaking out TestFlight crashes.
    /// Same one-shot-write semantics as `isEnabled`.
    nonisolated(unsafe) private(set) static var verboseEventsEnabled = false

    /// Call from `OpenCodeNexusApp.init()` *before* any other service runs.
    static func bootstrap() {
        let dsn = infoString("SentryDSN")
        let environment = infoString("SentryEnvironment") ?? "development"
        let release = bundleRelease()
        verboseEventsEnabled = infoBool("SentryVerboseEvents", default: true)

        // Always log boot to the file log — useful even with no Sentry.
        FileLogger.shared.log(.info, category: "CrashReporter",
            "Bootstrap. env=\(environment) release=\(release) sentry=\(dsn?.isEmpty == false ? "configured" : "disabled") verbose=\(verboseEventsEnabled)")

        guard let dsn, !dsn.isEmpty else {
            isEnabled = false
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.releaseName = release

            // Crashes & hangs: keep defaults, but make hang detection less aggressive
            // for TestFlight where users may be on slower networks.
            options.enableCrashHandler = true
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 3.0

            // Performance: 100% sampling during TestFlight; reduce in production.
            options.tracesSampleRate = 1.0
            options.enableAutoPerformanceTracing = true

            options.configureProfiling = {
                $0.sessionSampleRate = 1.0
                $0.lifecycle = .trace
            }

            options.experimental.enableLogs = true

            // Privacy: never send IPs / device identifiers by default.
            options.sendDefaultPii = false

            // Drop high-frequency SSE delta events and CI noise before they ship.
            // Per-token SSE updates would otherwise saturate the Sentry quota in
            // minutes during normal chat use.
            options.beforeSend = { event in
                if event.environment == "ci" { return nil }
                let messageText = event.message?.formatted ?? ""
                if messageText.contains("SSE: message.part.delta") { return nil }
                if messageText.contains("SSE: message.updated") { return nil }
                if messageText.contains("SSE: message.part.updated") { return nil }
                return event
            }

            // Mirror crash detection into the local log on next launch.
            options.onCrashedLastRun = { event in
                FileLogger.shared.log(
                    .fault,
                    category: "CrashReporter",
                    "Previous run crashed. eventId=\(event.eventId)"
                )
            }
        }

        isEnabled = true
        FileLogger.shared.log(.info, category: "CrashReporter", "Sentry started.")
    }

    // MARK: - Capture helpers

    static func capture(error: Error, category: String) {
        FileLogger.shared.log(.error, category: category, "\(error)")
        guard isEnabled else { return }
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: category, key: "category")
        }
    }

    static func capture(message: String, level: SentryLevel, category: String) {
        let fileLevel: FileLogger.Level
        switch level {
        case .debug: fileLevel = .debug
        case .info, .none: fileLevel = .info
        case .warning: fileLevel = .warning
        case .error: fileLevel = .error
        case .fatal: fileLevel = .fault
        @unknown default: fileLevel = .info
        }
        FileLogger.shared.log(fileLevel, category: category, message)
        guard isEnabled else { return }
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
            scope.setTag(value: category, key: "category")
        }
    }

    static func breadcrumb(category: String, message: String, level: SentryLevel = .info) {
        FileLogger.shared.log(.debug, category: category, "[breadcrumb] \(message)")
        guard isEnabled else { return }
        let crumb = Breadcrumb(level: level, category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: - Transactions

    /// Wrapper to hide Sentry's Span type from callers.
    class TransactionWrapper {
        private let span: Span?
        init(_ span: Span?) { self.span = span }
        func finish() { span?.finish() }
    }

    /// Start a Sentry transaction for an async flow. Returns nil when Sentry
    /// is disabled. Callers use `defer { txn?.finish() }`.
    @discardableResult
    static func transaction(name: String, operation: String) -> TransactionWrapper? {
        guard isEnabled else { return nil }
        let span = SentrySDK.startTransaction(name: name, operation: operation)
        return TransactionWrapper(span)
    }

    // MARK: - Plist helpers

    private static func infoString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // The Info.plist substitution leaves "$(SENTRY_DSN)" verbatim if the build setting is empty,
        // so treat that as "unset" too.
        if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
        return trimmed
    }

    private static func infoBool(_ key: String, default defaultValue: Bool) -> Bool {
        guard let raw = infoString(key)?.lowercased() else { return defaultValue }
        switch raw {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return defaultValue
        }
    }

    private static func bundleRelease() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let id = (info["CFBundleIdentifier"] as? String) ?? "ai.v1truv1us.opencode-mobile"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        let build = (info["CFBundleVersion"] as? String) ?? "0"
        return "\(id)@\(version)+\(build)"
    }
}
