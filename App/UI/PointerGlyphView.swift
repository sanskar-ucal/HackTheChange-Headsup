import HeadsUpKit
import SwiftUI

extension RGBAColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: Double(ns.redComponent), green: Double(ns.greenComponent),
                  blue: Double(ns.blueComponent), alpha: Double(ns.alphaComponent))
    }
}

/// Draws one pointer shape.
struct PointerGlyphView: View {
    let shape: PointerShape
    let color: Color
    let size: CGFloat
    var highContrast = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            glyph
                .frame(width: size, height: size)
                .scaleEffect(shape.emphasized ? 1.12 : 1)
                .opacity(shape.dimmed ? 0.45 : 1)
            if let badge = shape.badge {
                Image(systemName: badge)
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(size * 0.06)
                    .background(Circle().fill(Color.black.opacity(0.75)))
                    .offset(x: size * 0.18, y: -size * 0.12)
            }
        }
    }

    @ViewBuilder
    private var glyph: some View {
        let outline = highContrast ? Color.black.opacity(0.85) : Color.clear
        switch shape.glyph {
        case let .symbol(name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .shadow(color: outline, radius: 0.8)
                .shadow(color: outline, radius: 0.8)
        case .circle:
            ZStack {
                Circle().stroke(outline, lineWidth: size * 0.11)
                Circle().stroke(color, lineWidth: size * 0.07)
                if shape.emphasized { Circle().fill(color.opacity(0.25)) }
            }
            .padding(size * 0.08)
        case .ring:
            ZStack {
                Circle().stroke(outline, lineWidth: size * 0.06)
                Circle().stroke(color, lineWidth: size * 0.035)
            }
            .padding(size * 0.12)
        case .dot:
            Circle()
                .fill(color)
                .overlay(Circle().stroke(outline, lineWidth: 1.5))
                .frame(width: size * 0.32, height: size * 0.32)
        case .crosshair:
            ZStack {
                CrosshairShape().stroke(outline, lineWidth: size * 0.08)
                CrosshairShape().stroke(color, lineWidth: size * 0.04)
            }
        }
    }
}

/// Four arms around an open center, so the click point stays visible.
struct CrosshairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gap = rect.width * 0.14
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - gap))
        path.move(to: CGPoint(x: rect.midX, y: rect.midY + gap))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.1))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - gap, y: rect.midY))
        path.move(to: CGPoint(x: rect.midX + gap, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.midY))
        return path
    }
}
