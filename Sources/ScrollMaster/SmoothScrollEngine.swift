import Foundation

/// Parameters for smooth scrolling algorithm
public struct SmoothScrollParameters: Equatable, Codable {
    /// Smoothing duration in seconds (how long to spread the scroll over)
    public var duration: TimeInterval

    /// Interpolation curve type
    public var curve: InterpolationCurve

    /// Multiplier for scroll distance (1.0 = no change)
    public var distanceMultiplier: Double

    /// Minimum delta to consider (below this is ignored)
    public var minimumDelta: Double

    public init(
        duration: TimeInterval = 0.3,
        curve: InterpolationCurve = .easeOut,
        distanceMultiplier: Double = 1.0,
        minimumDelta: Double = 0.01
    ) {
        self.duration = duration
        self.curve = curve
        self.distanceMultiplier = distanceMultiplier
        self.minimumDelta = minimumDelta
    }

    /// Default parameters
    public static var `default`: SmoothScrollParameters {
        SmoothScrollParameters()
    }
}

/// Interpolation curve types for smooth scrolling
public enum InterpolationCurve: String, Codable, Equatable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    /// Apply the curve to a normalized time value (0.0 to 1.0)
    /// - Parameter t: Normalized time (0.0 = start, 1.0 = end)
    /// - Returns: Interpolated value (0.0 to 1.0)
    public func apply(_ t: Double) -> Double {
        let clamped = max(0.0, min(1.0, t))

        switch self {
        case .linear:
            return clamped

        case .easeIn:
            return clamped * clamped

        case .easeOut:
            return 1.0 - (1.0 - clamped) * (1.0 - clamped)

        case .easeInOut:
            if clamped < 0.5 {
                return 2.0 * clamped * clamped
            } else {
                let f = clamped - 1.0
                return 1.0 - 2.0 * f * f
            }
        }
    }
}

/// Represents an active smooth scroll animation
struct SmoothScrollAnimation {
    /// Target vertical delta to reach
    let targetVertical: Double

    /// Target horizontal delta to reach
    let targetHorizontal: Double

    /// Start time of the animation
    let startTime: TimeInterval

    /// Duration of the animation
    let duration: TimeInterval

    /// Interpolation curve
    let curve: InterpolationCurve

    /// Current accumulated vertical delta
    var accumulatedVertical: Double = 0.0

    /// Current accumulated horizontal delta
    var accumulatedHorizontal: Double = 0.0

    /// Check if animation is complete
    func isComplete(at time: TimeInterval) -> Bool {
        time >= startTime + duration
    }

    /// Get the progress (0.0 to 1.0) at a given time
    func progress(at time: TimeInterval) -> Double {
        guard duration > 0 else { return 1.0 }

        let elapsed = time - startTime
        return min(1.0, max(0.0, elapsed / duration))
    }

    /// Get the interpolated delta at a given time (returns what hasn't been accumulated yet)
    mutating func deltaAt(time: TimeInterval) -> (vertical: Double, horizontal: Double) {
        let t = progress(at: time)
        let interpolated = curve.apply(t)

        let targetV = targetVertical * interpolated
        let targetH = targetHorizontal * interpolated

        let deltaV = targetV - accumulatedVertical
        let deltaH = targetH - accumulatedHorizontal

        accumulatedVertical = targetV
        accumulatedHorizontal = targetH

        return (deltaV, deltaH)
    }
}

/// Smooth scrolling engine
public final class SmoothScrollEngine {
    private var parameters: SmoothScrollParameters
    private var animations: [SmoothScrollAnimation] = []
    private let queue = DispatchQueue(label: "com.mactools.smoothscroll", attributes: .concurrent)
    private let timeProvider: () -> TimeInterval

    public init(
        parameters: SmoothScrollParameters = .default,
        timeProvider: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    ) {
        self.parameters = parameters
        self.timeProvider = timeProvider
    }

    // MARK: - Public Interface

    /// Add a discrete scroll input
    /// - Parameters:
    ///   - vertical: Vertical scroll delta
    ///   - horizontal: Horizontal scroll delta
    public func addInput(vertical: Double, horizontal: Double) {
        // Filter out tiny deltas
        let filteredV = abs(vertical) < parameters.minimumDelta ? 0.0 : vertical
        let filteredH = abs(horizontal) < parameters.minimumDelta ? 0.0 : horizontal

        guard filteredV != 0.0 || filteredH != 0.0 else { return }

        // Apply distance multiplier
        let scaledV = filteredV * parameters.distanceMultiplier
        let scaledH = filteredH * parameters.distanceMultiplier

        queue.async(flags: .barrier) {
            let now = self.timeProvider()

            let animation = SmoothScrollAnimation(
                targetVertical: scaledV,
                targetHorizontal: scaledH,
                startTime: now,
                duration: self.parameters.duration,
                curve: self.parameters.curve
            )

            self.animations.append(animation)
        }
    }

    /// Get the current smooth scroll delta (call this on each frame)
    /// - Returns: (vertical, horizontal) deltas for this frame
    public func tick() -> (vertical: Double, horizontal: Double) {
        queue.sync(flags: .barrier) {
            let now = timeProvider()
            var totalV = 0.0
            var totalH = 0.0

            // Process all active animations
            animations = animations.compactMap { animation in
                var anim = animation

                if anim.isComplete(at: now) {
                    // Animation complete, get final delta
                    let (v, h) = anim.deltaAt(time: now)
                    totalV += v
                    totalH += h
                    return nil // Remove completed animation
                } else {
                    // Animation ongoing, get current delta
                    let (v, h) = anim.deltaAt(time: now)
                    totalV += v
                    totalH += h
                    return anim // Keep animation
                }
            }

            return (totalV, totalH)
        }
    }

    /// Update parameters
    public func updateParameters(_ newParams: SmoothScrollParameters) {
        queue.async(flags: .barrier) {
            self.parameters = newParams
        }
    }

    /// Get current parameters
    public func getParameters() -> SmoothScrollParameters {
        queue.sync {
            parameters
        }
    }

    /// Clear all active animations
    public func reset() {
        queue.async(flags: .barrier) {
            self.animations.removeAll()
        }
    }

    /// Check if there are active animations
    public var hasActiveAnimations: Bool {
        queue.sync {
            !animations.isEmpty
        }
    }

    /// Number of active animations
    public var activeAnimationCount: Int {
        queue.sync {
            animations.count
        }
    }
}
