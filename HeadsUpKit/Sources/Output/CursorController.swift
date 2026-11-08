import CoreGraphics
import Foundation

/// Keys HeadsUp can press on the user's behalf.
public enum KeyCommand: Sendable, Equatable {
    case escape
    /// Jump the frontmost app to the top of its content (see `ScrollToTopKey`).
    case scrollToTop
}

/// Which key scrolls the frontmost app to the top. Browsers get Home, which works even when no
/// text field is focused; everything else gets ⌘↑.
public enum ScrollToTopKey: Sendable, Equatable {
    case commandUp
    case home

    public static let browserBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Beta",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
    ]

    public static func key(forFrontmostBundleID bundleID: String?) -> ScrollToTopKey {
        guard let bundleID, browserBundleIDs.contains(bundleID) else { return .commandUp }
        return .home
    }
}

/// Posts synthetic pointer and keyboard input.
@MainActor
public protocol CursorController: AnyObject {
    var currentPosition: CGPoint { get }
    func move(to point: CGPoint)
    func click(at point: CGPoint)
    func pressKey(_ key: KeyCommand)
}
