import SwiftUI

/// A modifier that applies a variable blur based on how close the view's content is to the edges
/// of a horizontal scrolling region. Content near the center is sharp; it gets blurrier toward edges.
/// For WorkoutTab and ActivitiesTab
struct VariableBlurModifier: ViewModifier {
    let maxRadius: CGFloat
    let coordinateSpace: CoordinateSpace

    @State private var frameInSpace: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: VariableBlurFramePreferenceKey.self, value: proxy.frame(in: coordinateSpace))
                }
            )
            .onPreferenceChange(VariableBlurFramePreferenceKey.self) { newValue in
                frameInSpace = newValue
            }
            .modifier(VariableBlurApplier(maxRadius: maxRadius, frameInSpace: frameInSpace))
    }
}

private struct VariableBlurApplier: ViewModifier {
    let maxRadius: CGFloat
    let frameInSpace: CGRect

    @Environment(\.self) private var env

    func body(content: Content) -> some View {
        GeometryReader { outer in
            // Compute how far the content's center is from the visible center horizontally.
            let visible = outer.frame(in: .named("ActivitiesScrollSpace"))
            let contentCenterX = frameInSpace.midX
            let visibleCenterX = visible.midX
            let distance = abs(contentCenterX - visibleCenterX)
            // Normalize distance into 0...1 using half the visible width as the falloff range.
            let halfWidth = max(visible.width / 2, 1)
            let normalized = min(max(distance / halfWidth, 0), 1)
            let radius = normalized * maxRadius

            content
                .blur(radius: radius, opaque: false)
        }
    }
}

private struct VariableBlurFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension View {
    /// Applies a variable blur that increases toward the horizontal edges of a named coordinate space.
    /// - Parameters:
    ///   - maxRadius: The maximum blur radius to apply at the far edges.
    ///   - coordinateSpace: The coordinate space to measure against. Defaults to `.named("ActivitiesScrollSpace")`.
    func variableBlur(maxRadius: CGFloat, coordinateSpace: CoordinateSpace = .named("ActivitiesScrollSpace")) -> some View {
        modifier(VariableBlurModifier(maxRadius: maxRadius, coordinateSpace: coordinateSpace))
    }
}
