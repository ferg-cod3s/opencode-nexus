import Foundation

struct SessionStatus: Codable {
    let status: String

    var isBusy: Bool { status == "busy" }
    var isRetry: Bool { status == "retry" }
    var isIdle: Bool { status == "idle" }
    var isWaitingForInput: Bool { status == "waiting-for-input" }
    var isFailed: Bool { status == "error" || status == "failed" }
    var needsAttention: Bool { isFailed || isWaitingForInput }
}
