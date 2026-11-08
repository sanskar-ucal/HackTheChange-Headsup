import CoreGraphics
import Foundation

/// Keys HeadsUp can press on the user's behalf.
public enum KeyCommand: Sendable, Equatable {
    case escape
}

/// Posts synthetic pointer and keyboard input.
@MainActor
public protocol CursorController: AnyObject {
    var currentPosition: CGPoint { get }
    func move(to point: CGPoint)
    func click(at point: CGPoint)
    func pressKey(_ key: KeyCommand)
}
