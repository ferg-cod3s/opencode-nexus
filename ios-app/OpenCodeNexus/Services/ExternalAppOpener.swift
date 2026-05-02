import UIKit

enum ExternalApp: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case vscode = "vscode"
    case cursor = "cursor"
    case zed = "zed"
    case xcode = "xcode"
    case textmate = "textmate"
    case sublimetext = "sublimetext"
    case iterm2 = "iterm2"
    case ghostty = "ghostty"
    case warp = "warp"
    case terminal = "terminal"
    case files = "files"
    
    var displayName: String {
        switch self {
        case .vscode: "Visual Studio Code"
        case .cursor: "Cursor"
        case .zed: "Zed"
        case .xcode: "Xcode"
        case .textmate: "TextMate"
        case .sublimetext: "Sublime Text"
        case .iterm2: "iTerm2"
        case .ghostty: "Ghostty"
        case .warp: "Warp"
        case .terminal: "Terminal"
        case .files: "Files"
        }
    }
    
    var urlScheme: String {
        switch self {
        case .vscode: "vscode://"
        case .cursor: "cursor://"
        case .zed: "zed://"
        case .xcode: "xcode://"
        case .textmate: "txmt://"
        case .sublimetext: "subl://"
        case .iterm2: "iterm2://"
        case .ghostty: "ghostty://"
        case .warp: "warp://"
        case .terminal: "terminal://"
        case .files: "shareddocuments://"
        }
    }
    
    func urlForFile(path: String) -> URL? {
        switch self {
        case .vscode:
            return URL(string: "vscode://file/\(path)")
        case .cursor:
            return URL(string: "cursor://file/\(path)")
        case .zed:
            return URL(string: "zed://file/\(path)")
        case .files:
            return URL(string: "shareddocuments://\(path)")
        default:
            return URL(string: "\(urlScheme)\(path)")
        }
    }
}

@MainActor
final class ExternalAppOpener {
    static let shared = ExternalAppOpener()
    
    func canOpen(_ app: ExternalApp) -> Bool {
        guard let url = URL(string: app.urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func openFile(path: String, with app: ExternalApp) {
        guard let url = app.urlForFile(path: path) else { return }
        Task { await UIApplication.shared.open(url) }
    }
    
    func openURL(_ url: URL) {
        Task { await UIApplication.shared.open(url) }
    }
    
    func availableApps() -> [ExternalApp] {
        ExternalApp.allCases.filter { canOpen($0) }
    }
}
