import Foundation

extension Date {
    private nonisolated(unsafe) static let _formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var relativeString: String {
        Self._formatter.localizedString(for: self, relativeTo: Date())
    }
}
