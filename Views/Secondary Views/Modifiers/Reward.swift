import SwiftUI
import SwiftData

/// Represents a reward that can be redeemed by the user.
@Model
final class Reward {
    /// Unique identifier for the reward.
    var id: UUID
    /// Title or name of the reward.
    var title: String
    /// Cost of the reward in points.
    var costPoints: Int
    /// Effect of the reward.
    var effect: RewardEffect
    /// Indicates whether the reward is currently active.
    var isActive: Bool

    /// Initializes a new reward instance.
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new UUID.
    ///   - title: Title of the reward.
    ///   - costPoints: Cost in points.
    ///   - effect: The reward effect.
    ///   - isActive: Whether the reward is active, defaults to true.
    init(
        id: UUID = UUID(),
        title: String,
        costPoints: Int,
        effect: RewardEffect,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.costPoints = costPoints
        self.effect = effect
        self.isActive = isActive
    }

    /// A human-readable description of the reward's effect.
    var description: String {
        switch effect {
        case .screenTime(let minutes):
            return "+\(minutes) min screen time"
        case .themeChange(let themeName):
            if let name = themeName, !name.isEmpty {
                return "Change app theme to Cosmic Orange."
            } else {
                return "Change app theme"
            }
        }
    }
}

/// Describes the effect of a reward.
enum RewardEffect: Codable, Hashable {
    /// Adds additional screen time in minutes.
    case screenTime(minutes: Int)
    /// Changes the app's theme optionally to a specified theme name.
    case themeChange(themeName: String?)

    enum CodingKeys: String, CodingKey {
        case type
        case minutes
        case themeName
    }

    enum EffectType: String, Codable {
        case screenTime
        case themeChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EffectType.self, forKey: .type)
        switch type {
        case .screenTime:
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .screenTime(minutes: minutes)
        case .themeChange:
            let themeName = try container.decodeIfPresent(String.self, forKey: .themeName)
            self = .themeChange(themeName: themeName)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .screenTime(let minutes):
            try container.encode(EffectType.screenTime, forKey: .type)
            try container.encode(minutes, forKey: .minutes)
        case .themeChange(let themeName):
            try container.encode(EffectType.themeChange, forKey: .type)
            try container.encodeIfPresent(themeName, forKey: .themeName)
        }
    }
}
