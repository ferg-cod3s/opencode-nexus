import Foundation

extension Date {
    var relativeString: String {
        RelativeDateTimeFormatter().localizedString(for: self, relativeTo: Date())
    }
}
