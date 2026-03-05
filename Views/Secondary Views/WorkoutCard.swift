//
//  WorkoutCard.swift
//  ActivTimer
//
//  Created by Katelyn on 2/4/26.
//

import SwiftUI
import UIKit
import ImageIO
import _SwiftData_SwiftUI

final class GIFCache {
    private let cache = NSCache<NSString, UIImage>()

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

final class GIFLoader {
    nonisolated(unsafe) static let shared = GIFLoader()
    private let cache = GIFCache()
    private let decodeQueue = DispatchQueue(label: "gif.decode.queue", qos: .userInitiated)

    struct PreloadedGIF {
        let name: String
        let image: UIImage?
    }

    func resolveResource(name: String) -> (name: String, ext: String)? {
        if name.lowercased().hasSuffix(".gif") {
            return (String(name.dropLast(4)), "gif")
        } else {
            return (name, "gif")
        }
    }

    /// Returns a cached animated image for a given bundle resource name if available.
    func cachedImage(forName name: String) -> UIImage? {
        guard let res = resolveResource(name: name),
              let url = Bundle.main.url(forResource: res.name, withExtension: res.ext) else {
            return nil
        }
        return cache.image(forKey: url.path)
    }

    func preload(names: [String]) {
        // Fast-path: if data is small and available, decode and cache synchronously to avoid first-use placeholder.
        for name in names {
            guard let res = self.resolveResource(name: name),
                  let url = Bundle.main.url(forResource: res.name, withExtension: res.ext) else { continue }
            if self.cache.image(forKey: url.path) == nil,
               let data = try? Data(contentsOf: url),
               let animatedImage = UIImage.animatedImageWithGIFData(data) {
                self.cache.setImage(animatedImage, forKey: url.path)
            }
        }
        // Background pass to cover any misses without blocking UI.
        let cache = self.cache
        let resolver = self.resolveResource
        self.decodeQueue.async { [names] in
            for name in names {
                guard let res = resolver(name),
                      let url = Bundle.main.url(forResource: res.name, withExtension: res.ext),
                      cache.image(forKey: url.path) == nil,
                      let data = try? Data(contentsOf: url),
                      let animatedImage = UIImage.animatedImageWithGIFData(data) else {
                    continue
                }
                cache.setImage(animatedImage, forKey: url.path)
            }
        }
    }

    func load(name: String, completion: @MainActor @escaping (UIImage?) -> Void) {
        // Resolve resource first
        guard let res = self.resolveResource(name: name),
              let url = Bundle.main.url(forResource: res.name, withExtension: res.ext) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // If we already have it cached, return immediately without hopping to background.
        if let cached = self.cache.image(forKey: url.path) {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        // Otherwise decode in background and cache.
        decodeQueue.async {
            if let cached = self.cache.image(forKey: url.path) {
                DispatchQueue.main.async { completion(cached) }
                return
            }
            guard let data = try? Data(contentsOf: url),
                  let animatedImage = UIImage.animatedImageWithGIFData(data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.cache.setImage(animatedImage, forKey: url.path)
            DispatchQueue.main.async { completion(animatedImage) }
        }
    }
}

struct GifView: View {
    let name: String

    enum Phase: CaseIterable { case small, large }

    
    //Use PhaseAnimator to smoothly animate GIFs with ease
    var body: some View {
        PhaseAnimator(Phase.allCases, trigger: name) { phase in
            AnimatedGIFView(gifName: name)
                .scaleEffect(phase == .small ? 0.98 : 1.02)
                .shadow(color: .indigo.opacity(phase == .small ? 0.15 : 0.35),
                        radius: phase == .small ? 6 : 14,
                        x: 0, y: phase == .small ? 1 : 3)
        } animation: { phase in
            switch phase {
            case .small: .easeInOut(duration: 1.2)
            case .large: .easeInOut(duration: 1.2)
            }
        }
        .onAppear { GIFLoader.shared.preload(names: [name]) }
        .accessibilityHidden(true)
    }
}

// A UIViewRepresentable that plays animated GIFs from the app bundle in ActivitiesTab using UIImageView animation.
private struct AnimatedGIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        let currentGifName = gifName

        // Try to resolve and read from cache synchronously to avoid placeholder when possible.
        if let cached = GIFLoader.shared.cachedImage(forName: currentGifName) {
            uiView.image = cached
            if !(uiView.isAnimating) { uiView.startAnimating() }
            return
        }

        // Show a lightweight placeholder only if nothing cached yet.
        uiView.stopAnimating()
        uiView.image = UIImage(systemName: "photo")

        // Kick off load (will return immediately if cache fills during this pass)
        GIFLoader.shared.load(name: currentGifName) { animatedImage in
            guard let animatedImage = animatedImage else { return }
            if currentGifName == gifName { // still the same request
                uiView.image = animatedImage
                uiView.startAnimating()
            }
        }
    }
}

// MARK: - UIImage + GIF decoding helper
private extension UIImage {
    /// Creates an animated UIImage from GIF data using ImageIO.
    static func animatedImageWithGIFData(_ data: Data, defaultFrameDuration: Double = 0.08) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var durations: [Double] = []

        for i in 0..<frameCount {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let duration = UIImage.frameDuration(at: i, source: source) ?? defaultFrameDuration
            images.append(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up))
            durations.append(duration)
        }

        guard !images.isEmpty else { return nil }

        // Total duration is the sum of per-frame durations.
        let totalDuration = durations.reduce(0, +)
        return UIImage.animatedImage(with: images, duration: max(totalDuration, defaultFrameDuration))
    }

    /// Reads GIF frame duration from the frame's properties, honoring unclamped values.
    private static func frameDuration(at index: Int, source: CGImageSource) -> Double? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifDict = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return nil
        }

        // Prefer unclamped delay time; fall back to clamped.
        let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifDict[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped

        // Some GIFs specify 0; use a sensible default if so.
        if let d = duration, d > 0.011 {
            return d
        } else {
            return 0.08
        }
    }
}

private extension View {
    /// Applies the given transform if the condition is true.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct WorkoutCard<Expanded: View, S: Shape>: View {
    // External control so ActivitiesTab can drive the animation
    @Binding var isExpanded: Bool
    let sourceID: String
    let namespace: Namespace.ID
    let shape: S
    let glass: Glass
    @ViewBuilder var expandedContent: () -> Expanded
    
    //Confetti trigger when user completes a workout
    @State private var isCelebrating: Bool = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            // The caller provides the card content; we keep a default placeholder to avoid breaking previews.
            Text("Placeholder Content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
        .buttonStyle(FluidZoomTransitionButtonStyle(id: sourceID, namespace: namespace, shape: shape, glass: glass))
        .sheet(isPresented: $isExpanded) {
            expandedContent()
                .navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        }
    }
}

struct ExpandedContent: View {
    @Binding var isExpanded: Bool
    var title: String = "Expanded Content"
    var mediaFilename: String = ""
    var description: String = ""
    var onCompleted: () -> Void = {}
    
    enum ActivityKind {
        case workout
        case meditation
        case stretch
    }

    var kind: ActivityKind = .workout

    @Environment(\.modelContext) private var modelContext
    @Query private var pointsList: [Points]

    private func awardMinutesForCompletion() {
        // Get or create the Points store
        let points: Points
        if let existing = pointsList.first {
            points = existing
        } else {
            let newPoints = Points()
            modelContext.insert(newPoints)
            points = newPoints
        }

        // Determine minutes to award based on activity kind, mapping to RewardsTab's demo values
        let minutes: Int
        switch kind {
        case .meditation:
            minutes = 5
        case .stretch:
            minutes = 15
        case .workout:
            minutes = 30
        }

        // Add minutes and points 1:1
        points.screenTimeBalanceMinutes += max(0, minutes)
        points.total += max(0, minutes)

        // Set next break countdown base: 15 minutes + awarded minutes
        let baseSeconds = 900 // 15 minutes
        let awardedSeconds = minutes * 60
        UserDefaults.standard.set(baseSeconds + awardedSeconds, forKey: "nextCountdownBaseSeconds")

        // Notify HomeTab to reset its timer now that the awarded time has been applied
        NotificationCenter.default.post(name: Notification.Name("ActivityCompletedAwardedTime"), object: nil)

        do { try modelContext.save() } catch { print("Failed saving awarded minutes: \(error)") }
    }

    @State private var currentStepIndex: Int = 0
    // Multi Steps buttons and UI to make the workout easy to read step by step
    private var steps: [String] {
        // Support multiple delimiters:
        // - Lines containing only --- act as hard separators
        // - Otherwise, split on single newlines
        // - Normalize multiple blank lines
        let normalized = description
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            // Collapse 3+ newlines to a double newline to avoid accidental empties
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        // First split on custom delimiter lines (--- on its own line)
        let hardParts = normalized
            .components(separatedBy: "\n---\n")

        // For each hard part, further split on single newlines into steps
        let parts = hardParts
            .flatMap { $0.components(separatedBy: "\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.isEmpty ? [description] : parts
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // Top bar: title on the left, done button on the right
                HStack(alignment: .center) {

                    Text(title)
                        .font(.title.bold())
                        .padding(.top, 15) // Lower the title a bit so it doesnt get squshed
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.indigo)

                    Button {

                        // Trigger completion in ActivitiesTab and dismiss. ActivitiesTab will handle confetti.
                        onCompleted()
                        awardMinutesForCompletion()
                        // Dismiss after a short delay to allow any completion UI to appear.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isExpanded = false
                        }

                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .contentShape(Capsule())
                    }
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.top, 15) // Lower the button a bit so it doesnt get squshed
                    .shadow(radius: 2, y: 1)
                    .accessibilityLabel("Mark workout as done, so you can get rewards + more screen time!")
                }

                // Media area: Try to show the GIF if available; otherwise show a placeholder image.
                Group {
                    if !mediaFilename.isEmpty {
                        // Attempt to load and display GIF from ActivitiesTab's GifView.
                        GifView(name: mediaFilename)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.secondary.opacity(0.2))
                            )
                            .accessibilityLabel("Workout or activity animation")
                    } else {
                        // Placeholder when no media is provided
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.secondary.opacity(0.2))
                            )
                            .accessibilityLabel("No animation available")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Current step content
                    ScrollView {
                        Text(steps[min(currentStepIndex, max(steps.count - 1, 0))])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 220) // Compact scroll area so buttons stay put on iPhone

                    // Pagination controls if multiple steps with Back and forward buttons
                    if steps.count > 1 {
                        HStack {
                            Button {
                                withAnimation(.snappy) {
                                    currentStepIndex = max(currentStepIndex - 1, 0)
                                }
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                                    .labelStyle(.titleAndIcon)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 5)
                            }
                            .disabled(currentStepIndex == 0)
                            .buttonStyle(.glassProminent)

                            Spacer()

                            // Page indicators
                            HStack(spacing: 6) {
                                ForEach(0..<steps.count, id: \.self) { idx in
                                    Circle()
                                        .fill(idx == currentStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .accessibilityHidden(true)
                                }
                            }

                            Spacer()

                            Button {
                                if currentStepIndex == steps.count - 1 {
                                    // Final step: complete and dismiss
                                    onCompleted()
                                    awardMinutesForCompletion()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isExpanded = false
                                    }
                                } else {
                                    // Advance to next step
                                    withAnimation(.snappy) {
                                        currentStepIndex = min(currentStepIndex + 1, steps.count - 1)
                                    }
                                }
                            } label: {
                                Label(currentStepIndex == steps.count - 1 ? "Complete" : "Next", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(currentStepIndex == steps.count - 1 ? .green : .purple)
                        }
                        .padding(.top, 4)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Step navigation to perform workout or task")
                    }
                }

                Spacer()
            }
        }
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        .padding(.horizontal)
    }
}

struct FluidZoomTransitionButtonStyle<S: Shape>: ButtonStyle {
    var id: String
    var namespace: Namespace.ID
    
    var shape: S
    
    var glass: Glass
    @State private var hapticsTrigger: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 25)
            .contentShape(shape)
            .matchedTransitionSource(id: id, in: namespace)
            .glassEffect(glass.interactive(), in: shape)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticsTrigger)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                guard newValue else { return }
                // isPressed will become false upon interacting with workout or activity.
                hapticsTrigger.toggle()
            }
    }
}

#Preview {
    ContentView()
}

