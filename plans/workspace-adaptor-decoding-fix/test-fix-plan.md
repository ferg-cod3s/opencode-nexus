# Fix: UpdateCheckerTests Compilation Error

## Problem
`UpdateCheckerTests.swift` fails to compile because `MockOpenCodeClient` subclasses `OpenCodeClient`, which is a `final class`. This blocks all tests from running.

## Root Cause
- `OpenCodeClient` has been `final class` since the initial project creation (commit `b16a3df`)
- `UpdateCheckerTests.swift` is untracked and was added without accounting for this

## Solution: Protocol-Based Mocking

### Step 1: Define `HealthCheckable` Protocol
**File**: `ios-app/OpenCodeNexus/Services/UpdateChecker.swift`

Add a protocol that `OpenCodeClient` already implicitly conforms to:

```swift
protocol HealthCheckable {
    func healthCheck() async throws -> HealthResponse
}

extension OpenCodeClient: HealthCheckable {}
```

### Step 2: Update `UpdateChecker` Signature
**File**: `ios-app/OpenCodeNexus/Services/UpdateChecker.swift`

Change:
```swift
func checkForUpdate(client: OpenCodeClient) async -> UpdateInfo?
```
To:
```swift
func checkForUpdate(client: some HealthCheckable) async -> UpdateInfo?
```

### Step 3: Refactor `MockOpenCodeClient`
**File**: `ios-app/OpenCodeNexusTests/UpdateCheckerTests.swift`

Replace the subclass with a protocol conformance:

```swift
private class MockHealthCheckable: HealthCheckable {
    private let healthResponse: HealthResponse?
    private let shouldFail: Bool

    init(healthResponse: HealthResponse? = nil, shouldFail: Bool = false) {
        self.healthResponse = healthResponse
        self.shouldFail = shouldFail
    }

    func healthCheck() async throws -> HealthResponse {
        if shouldFail {
            throw URLError(.badServerResponse)
        }
        guard let response = healthResponse else {
            throw URLError(.badServerResponse)
        }
        return response
    }
}
```

### Step 4: Update Test Method Calls
**File**: `ios-app/OpenCodeNexusTests/UpdateCheckerTests.swift`

Replace:
- `MockOpenCodeClient(healthResponse: ...)` → `MockHealthCheckable(healthResponse: ...)`
- `MockOpenCodeClient(shouldFail: true)` → `MockHealthCheckable(shouldFail: true)`

## Verification
- Build tests: `xcodebuild test ...` should compile and run
- All existing `UpdateChecker` tests should pass
- No regression in `ChatView.swift` (the only caller of `checkForUpdate`)

## Files Modified
1. `ios-app/OpenCodeNexus/Services/UpdateChecker.swift` — Add protocol + update signature
2. `ios-app/OpenCodeNexusTests/UpdateCheckerTests.swift` — Refactor mock class
