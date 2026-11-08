import Foundation

/// The parts of a focused accessibility element that decide whether to listen.
public struct FocusedElementInfo: Sendable, Equatable {
    public var role: String?
    public var subrole: String?
    public var isValueSettable: Bool
    public var placeholder: String?
    public var descriptionText: String?
    public var title: String?
    public var identifier: String?

    public init(role: String?, subrole: String? = nil, isValueSettable: Bool = true, placeholder: String? = nil,
                descriptionText: String? = nil, title: String? = nil, identifier: String? = nil) {
        self.role = role
        self.subrole = subrole
        self.isValueSettable = isValueSettable
        self.placeholder = placeholder
        self.descriptionText = descriptionText
        self.title = title
        self.identifier = identifier
    }
}

/// A focused element plus an opaque handle (an `AXUIElement` in production) that the text inserter writes into.
public struct FocusedElement {
    public var info: FocusedElementInfo
    public var handle: AnyObject?

    public init(info: FocusedElementInfo, handle: AnyObject? = nil) {
        self.info = info
        self.handle = handle
    }
}

/// Reads the system-wide focused element and reports focus changes in the frontmost app.
@MainActor
public protocol FocusedElementReader: AnyObject {
    func focusedElement() -> FocusedElement?
    var onFocusChange: (@MainActor () -> Void)? { get set }
}

/// Decides whether a focused element should start voice input.
public enum TextFieldDetector {
    public static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]
    public static let searchSubrole = "AXSearchField"
    public static let secureSubrole = "AXSecureTextField"

    public static func isSecure(_ info: FocusedElementInfo) -> Bool {
        info.role == secureSubrole || info.subrole == secureSubrole
    }

    public static func isTextTarget(_ info: FocusedElementInfo) -> Bool {
        guard !isSecure(info), info.isValueSettable else { return false }
        if let role = info.role, textRoles.contains(role) { return true }
        return info.subrole == searchSubrole
    }

    public static func isSearchField(_ info: FocusedElementInfo) -> Bool {
        if info.subrole == searchSubrole { return true }
        let hints = [info.placeholder, info.descriptionText, info.title, info.identifier]
        return hints.contains { $0?.lowercased().contains("search") ?? false }
    }

    public static func shouldListen(_ info: FocusedElementInfo, trigger: VoiceInputTrigger) -> Bool {
        guard isTextTarget(info) else { return false }
        switch trigger {
        case .off: return false
        case .allTextFields: return true
        case .searchFieldsOnly: return isSearchField(info)
        }
    }
}
