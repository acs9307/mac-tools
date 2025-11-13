import Foundation
import CoreGraphics

/// Represents a transformation to apply to scroll events
public struct ScrollTransform: Equatable, Codable {
    /// Whether to invert the scroll direction
    public var invertVertical: Bool

    /// Whether to invert horizontal scroll direction
    public var invertHorizontal: Bool

    /// Multiplier for vertical scroll delta (1.0 = no change)
    public var verticalMultiplier: Double

    /// Multiplier for horizontal scroll delta (1.0 = no change)
    public var horizontalMultiplier: Double

    /// Whether smooth scrolling is enabled
    public var smoothScrollEnabled: Bool

    public init(
        invertVertical: Bool = false,
        invertHorizontal: Bool = false,
        verticalMultiplier: Double = 1.0,
        horizontalMultiplier: Double = 1.0,
        smoothScrollEnabled: Bool = false
    ) {
        self.invertVertical = invertVertical
        self.invertHorizontal = invertHorizontal
        self.verticalMultiplier = verticalMultiplier
        self.horizontalMultiplier = horizontalMultiplier
        self.smoothScrollEnabled = smoothScrollEnabled
    }

    /// Default (no transformation)
    public static var identity: ScrollTransform {
        ScrollTransform()
    }

    /// Apply transformation to scroll deltas
    /// - Parameters:
    ///   - vertical: Vertical scroll delta
    ///   - horizontal: Horizontal scroll delta
    /// - Returns: Transformed (vertical, horizontal) deltas
    public func apply(vertical: Double, horizontal: Double) -> (vertical: Double, horizontal: Double) {
        let transformedVertical = vertical * verticalMultiplier * (invertVertical ? -1.0 : 1.0)
        let transformedHorizontal = horizontal * horizontalMultiplier * (invertHorizontal ? -1.0 : 1.0)

        return (transformedVertical, transformedHorizontal)
    }
}

/// Represents a scroll event with associated device information
public struct ScrollEvent: Equatable {
    /// Device stable ID that generated this event
    public let deviceID: String?

    /// Vertical scroll delta
    public let verticalDelta: Double

    /// Horizontal scroll delta
    public let horizontalDelta: Double

    /// Timestamp of the event
    public let timestamp: TimeInterval

    /// Whether this is a continuous (trackpad-style) scroll
    public let isContinuous: Bool

    public init(
        deviceID: String?,
        verticalDelta: Double,
        horizontalDelta: Double,
        timestamp: TimeInterval = Date.timeIntervalSinceReferenceDate,
        isContinuous: Bool = false
    ) {
        self.deviceID = deviceID
        self.verticalDelta = verticalDelta
        self.horizontalDelta = horizontalDelta
        self.timestamp = timestamp
        self.isContinuous = isContinuous
    }

    /// Create a new scroll event with transformed deltas
    public func applying(_ transform: ScrollTransform) -> ScrollEvent {
        let (newVertical, newHorizontal) = transform.apply(
            vertical: verticalDelta,
            horizontal: horizontalDelta
        )

        return ScrollEvent(
            deviceID: deviceID,
            verticalDelta: newVertical,
            horizontalDelta: newHorizontal,
            timestamp: timestamp,
            isContinuous: isContinuous
        )
    }
}
