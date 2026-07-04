// Input mapping, ported from the k_left..k_dash enum in celeste.c.
public enum CelesteButton: Int, CaseIterable {
    case left = 0
    case right = 1
    case up = 2
    case down = 3
    case jump = 4
    case dash = 5

    var bit: UInt8 { 1 << UInt8(rawValue) }
}

/// A simple bitmask of currently-held buttons, set by the host once per frame
/// before calling `CelesteEngine.update()`.
public struct CelesteInputState: Equatable {
    public var bits: UInt8

    public init(bits: UInt8 = 0) {
        self.bits = bits
    }

    public func isDown(_ button: CelesteButton) -> Bool {
        bits & button.bit != 0
    }

    public mutating func set(_ button: CelesteButton, _ down: Bool) {
        if down {
            bits |= button.bit
        } else {
            bits &= ~button.bit
        }
    }
}
