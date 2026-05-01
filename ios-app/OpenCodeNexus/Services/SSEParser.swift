import Foundation

struct SSEParser {
    private var dataBuffer: String = ""

    enum Result: Equatable {
        case event(SSEEvent)
        case malformed(String)
        case none
    }

    mutating func processLine(_ line: String) -> Result {
        if line.isEmpty {
            defer { dataBuffer = "" }
            guard !dataBuffer.isEmpty else { return .none }
            guard let jsonData = dataBuffer.data(using: .utf8) else {
                return .malformed(dataBuffer)
            }
            do {
                let event = try JSONDecoder().decode(SSEEvent.self, from: jsonData)
                return .event(event)
            } catch {
                return .malformed(dataBuffer)
            }
        } else if line.hasPrefix(":") {
            // SSE comment, ignore
        } else if line.hasPrefix("data: ") {
            let value = String(line.dropFirst(6))
            if dataBuffer.isEmpty {
                dataBuffer = value
            } else {
                dataBuffer += "\n" + value
            }
        }
        return .none
    }

    mutating func flush() -> Result {
        defer { dataBuffer = "" }
        guard !dataBuffer.isEmpty else { return .none }
        guard let jsonData = dataBuffer.data(using: .utf8) else {
            return .malformed(dataBuffer)
        }
        do {
            let event = try JSONDecoder().decode(SSEEvent.self, from: jsonData)
            return .event(event)
        } catch {
            return .malformed(dataBuffer)
        }
    }
}
