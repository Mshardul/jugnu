import Foundation

public struct ExactRational: Equatable, Sendable, Hashable, Codable {
    public let numerator: Int
    public let denominator: Int

    public init(_ numerator: Int, _ denominator: Int) {
        precondition(denominator != 0, "ExactRational denominator must be non-zero")
        let sign = denominator < 0 ? -1 : 1
        let num = numerator * sign
        let den = abs(denominator)
        let divisor = Self.gcd(abs(num), den)
        self.numerator = num / divisor
        self.denominator = den / divisor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let numerator = try container.decode(Int.self, forKey: .numerator)
        let denominator = try container.decode(Int.self, forKey: .denominator)
        guard denominator != 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .denominator,
                in: container,
                debugDescription: "denominator must be non-zero"
            )
        }
        self.init(numerator, denominator)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(numerator, forKey: .numerator)
        try container.encode(denominator, forKey: .denominator)
    }

    private enum CodingKeys: String, CodingKey {
        case numerator
        case denominator
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}

public func roundHalfUp(_ value: ExactRational, times multiplier: Int) -> Int {
    guard multiplier > 0, value.numerator > 0, value.denominator > 0 else { return 0 }
    let numerator = value.numerator * multiplier
    let denominator = value.denominator
    let quotient = numerator / denominator
    let remainder = numerator % denominator
    if remainder * 2 >= denominator {
        return quotient + 1
    }
    return quotient
}
