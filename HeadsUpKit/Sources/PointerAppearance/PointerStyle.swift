import Foundation

/// What to draw for the pointer body.
public enum PointerGlyph: Sendable, Equatable {
    case symbol(String)
    case circle
    case ring
    case dot
    case crosshair
}

/// One concrete pointer appearance.
public struct PointerShape: Sendable, Equatable {
    public var glyph: PointerGlyph
    public var badge: String?
    public var dimmed: Bool
    public var emphasized: Bool
    public var hotspot: NormalizedPoint

    public init(glyph: PointerGlyph, badge: String? = nil, dimmed: Bool = false,
                emphasized: Bool = false, hotspot: NormalizedPoint = .center) {
        self.glyph = glyph
        self.badge = badge
        self.dimmed = dimmed
        self.emphasized = emphasized
        self.hotspot = hotspot
    }
}

/// Maps pointer contexts to shapes.
public protocol PointerStyle: Sendable {
    var kind: PointerStyleKind { get }
    func shape(for context: PointerContext) -> PointerShape
}

extension PointerStyleKind {
    public var style: any PointerStyle {
        switch self {
        case .hand: return HandPointerStyle()
        case .greenCircle: return SimplePointerStyle(kind: .greenCircle, glyph: .circle)
        case .ring: return SimplePointerStyle(kind: .ring, glyph: .ring)
        case .dot: return SimplePointerStyle(kind: .dot, glyph: .dot)
        case .crosshair: return SimplePointerStyle(kind: .crosshair, glyph: .crosshair)
        }
    }
}

/// SF Symbol names for the small badges on the pointer.
enum PointerBadge {
    static func scroll(_ direction: ScrollDirection) -> String {
        switch direction {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .none: return "chevron.up.chevron.down"
        }
    }

    static let listening = "mic.fill"
    static let paused = "pause.fill"
}

/// Default style: a hand that changes shape with context.
public struct HandPointerStyle: PointerStyle {
    public let kind = PointerStyleKind.hand

    public init() {}

    public func shape(for context: PointerContext) -> PointerShape {
        let open = NormalizedPoint(x: 0.5, y: 0.04)
        switch context {
        case .idle, .tiltProgress:
            return PointerShape(glyph: .symbol("hand.raised.fill"), hotspot: open)
        case .hoveringClickable:
            return PointerShape(glyph: .symbol("hand.point.up.left.fill"), emphasized: true,
                                hotspot: NormalizedPoint(x: 0.12, y: 0.06))
        case .pressing:
            return PointerShape(glyph: .symbol("hand.tap.fill"), emphasized: true,
                                hotspot: NormalizedPoint(x: 0.45, y: 0.05))
        case let .scrolling(direction):
            return PointerShape(glyph: .symbol("hand.point.up.fill"), badge: PointerBadge.scroll(direction),
                                hotspot: NormalizedPoint(x: 0.42, y: 0.03))
        case .dragHint:
            return PointerShape(glyph: .symbol("hand.draw.fill"), hotspot: NormalizedPoint(x: 0.2, y: 0.1))
        case .listening:
            return PointerShape(glyph: .symbol("hand.raised.fill"), badge: PointerBadge.listening, hotspot: open)
        case .paused:
            return PointerShape(glyph: .symbol("hand.raised.fill"), badge: PointerBadge.paused,
                                dimmed: true, hotspot: open)
        }
    }
}

/// Geometric styles (green circle, ring, dot, crosshair): same glyph in every context.
public struct SimplePointerStyle: PointerStyle {
    public let kind: PointerStyleKind
    public let glyph: PointerGlyph

    public init(kind: PointerStyleKind, glyph: PointerGlyph) {
        self.kind = kind
        self.glyph = glyph
    }

    public func shape(for context: PointerContext) -> PointerShape {
        switch context {
        case .idle, .tiltProgress, .dragHint: return PointerShape(glyph: glyph)
        case .hoveringClickable, .pressing: return PointerShape(glyph: glyph, emphasized: true)
        case let .scrolling(direction): return PointerShape(glyph: glyph, badge: PointerBadge.scroll(direction))
        case .listening: return PointerShape(glyph: glyph, badge: PointerBadge.listening)
        case .paused: return PointerShape(glyph: glyph, badge: PointerBadge.paused, dimmed: true)
        }
    }
}
