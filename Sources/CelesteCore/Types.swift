// Basic value types used throughout the Celeste Classic engine.
// Ported from celeste.c (VEC, VECI, HITBOX, HAIR, PARTICLE, CLOUD).

public struct Vec: Equatable {
    public var x: Float
    public var y: Float

    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }
}

public struct VecI: Equatable {
    public var x: Int
    public var y: Int

    public init(x: Int = 0, y: Int = 0) {
        self.x = x
        self.y = y
    }
}

public struct HitBox: Equatable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int

    public init(x: Int = 0, y: Int = 0, w: Int = 8, h: Int = 8) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

public struct Hair: Equatable {
    public var x: Float = 0
    public var y: Float = 0
    public var size: Float = 1
    public var isLast: Bool = false
}

public struct Particle: Equatable {
    public var active: Bool = false
    public var x: Float = 0
    public var y: Float = 0
    public var s: Float = 0
    public var spd: Float = 0
    public var off: Float = 0
    public var c: Float = 0
    public var h: Float = 0
    public var t: Float = 0
    // used by dead particles, moved from spd
    public var spd2: Vec = Vec()
}

public struct Cloud: Equatable {
    public var x: Float = 0
    public var y: Float = 0
    public var spd: Float = 0
    public var w: Float = 0
}
