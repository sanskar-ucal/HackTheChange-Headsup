import ApplicationServices
import CoreGraphics
import Foundation

/// How text got into the field, so it can be undone.
public struct InsertionRecord {
    public enum Method: Equatable {
        /// `AXValue` was set; undo restores `original`.
        case setValue(original: String)
        /// Typed with key events; undo sends this many backspaces.
        case typed(characters: Int)
    }

    public var method: Method
    public var text: String
    public var handle: AnyObject?

    public init(method: Method, text: String, handle: AnyObject? = nil) {
        self.method = method
        self.text = text
        self.handle = handle
    }
}

/// Puts recognized text into the focused field.
@MainActor
public protocol TextInserter: AnyObject {
    func insert(_ text: String, into element: FocusedElement) -> InsertionRecord?
    func undo(_ record: InsertionRecord)
    /// Submits (e.g. runs the search).
    func pressReturn()
}

/// Appends via `kAXValueAttribute`; falls back to typing Unicode key events when the
/// value can't be set (or doesn't stick, as in some web views).
@MainActor
public final class AXTextInserter: TextInserter {
    private let source = CGEventSource(stateID: .hidSystemState)
    private static let returnKey: CGKeyCode = 36
    private static let deleteKey: CGKeyCode = 51

    public init() {}

    public func insert(_ text: String, into element: FocusedElement) -> InsertionRecord? {
        guard !text.isEmpty, AXIsProcessTrusted() else { return nil }
        if let handle = element.handle, CFGetTypeID(handle) == AXUIElementGetTypeID() {
            let field = handle as! AXUIElement  // swiftlint:disable:this force_cast — type checked
            let original = AX.string(field, kAXValueAttribute) ?? ""
            let combined = Self.join(original, text)
            if AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, combined as CFString) == .success,
               AX.string(field, kAXValueAttribute) == combined {
                return InsertionRecord(method: .setValue(original: original), text: text, handle: field)
            }
            let typed = Self.join(original, text).dropFirst(original.count)
            type(String(typed))
            return InsertionRecord(method: .typed(characters: typed.count), text: text, handle: field)
        }
        type(text)
        return InsertionRecord(method: .typed(characters: text.count), text: text)
    }

    public func undo(_ record: InsertionRecord) {
        switch record.method {
        case let .setValue(original):
            if let handle = record.handle, CFGetTypeID(handle) == AXUIElementGetTypeID() {
                let field = handle as! AXUIElement  // swiftlint:disable:this force_cast
                AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, original as CFString)
            }
        case let .typed(count):
            for _ in 0..<count { press(Self.deleteKey) }
        }
    }

    public func pressReturn() {
        press(Self.returnKey)
    }

    /// Adds a separating space when appending to existing text. Pure string logic with no
    /// access to the inserter's state, so it needs no main-actor isolation.
    nonisolated static func join(_ original: String, _ text: String) -> String {
        if original.isEmpty || original.hasSuffix(" ") { return original + text }
        return original + " " + text
    }

    private func type(_ text: String) {
        let units = Array(text.utf16)
        var index = 0
        while index < units.count {
            let chunk = Array(units[index..<min(index + 20, units.count)])
            index += chunk.count
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown) else { continue }
                event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private func press(_ key: CGKeyCode) {
        for isDown in [true, false] {
            CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)?.post(tap: .cghidEventTap)
        }
    }
}
