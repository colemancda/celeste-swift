// The general purpose entity type. Ported field-for-field from OBJ in
// celeste.c. Every entity "type" reuses this single class (as PICO-8's Lua
// objects were dynamically typed), so most instances only touch a handful of
// these fields depending on `type`.
//
// This is a reference type (rather than a value struct) on purpose: the
// original C code operates on `OBJ*` pointers into a shared array, so other
// entities observe a given entity's mutations mid-frame (e.g. a moving
// platform nudging the player, then later code in the same frame seeing the
// player's already-updated position). A class preserves that aliasing
// behavior directly; a struct copy would not.
public final class Entity {
    public var active: Bool = false
    public var id: Int = 0

    // inherited
    public var type: ObjType = .player
    public var collideable: Bool = true
    public var solids: Bool = true
    public var spr: Float = 0
    public var flipX: Bool = false
    public var flipY: Bool = false
    public var x: Float = 0
    public var y: Float = 0
    public var hitbox: HitBox = HitBox(x: 0, y: 0, w: 8, h: 8)
    public var spd: Vec = Vec()
    public var rem: Vec = Vec()

    // player
    public var pJump: Bool = false
    public var pDash: Bool = false
    public var grace: Int = 0
    public var jbuffer: Int = 0
    public var djump: Int = 0
    public var dashTime: Int = 0
    public var dashEffectTime: Int = 0
    public var dashTarget: Vec = Vec()
    public var dashAccel: Vec = Vec()
    public var sprOff: Float = 0
    public var wasOnGround: Bool = false
    public var hair: [Hair] = Array(repeating: Hair(), count: 5) // also player_spawn

    // player_spawn
    public var state: Int = 0
    public var delay: Int = 0
    public var target: Vec = Vec()

    // spring
    public var hideIn: Int = 0
    public var hideFor: Int = 0

    // balloon
    public var timer: Int = 0
    public var offset: Float = 0
    public var start: Float = 0

    // fruit
    public var off: Float = 0

    // fly_fruit
    public var fly: Bool = false
    public var step: Float = 0
    public var sfxDelay: Int = 0

    // lifeup
    public var duration: Int = 0
    public var flash: Float = 0

    // platform
    public var last: Float = 0
    public var dir: Float = 0

    // message
    public var text: String = ""
    public var index: Float = 0
    public var off2: VecI = VecI()

    // big chest
    public var particles: [Particle] = Array(repeating: Particle(), count: 50)
    public var particleCount: Int = 0

    // flag
    public var score: Int = 0
    public var show: Bool = false

    public init() {}

    /// Deep value copy, used to emulate `player_dummy_copy = *this` in
    /// PLAYER_update: once the player object is destroyed mid-update, the
    /// rest of the function keeps operating on a detached snapshot.
    func copy() -> Entity {
        let e = Entity()
        e.active = active
        e.id = id
        e.type = type
        e.collideable = collideable
        e.solids = solids
        e.spr = spr
        e.flipX = flipX
        e.flipY = flipY
        e.x = x
        e.y = y
        e.hitbox = hitbox
        e.spd = spd
        e.rem = rem
        e.pJump = pJump
        e.pDash = pDash
        e.grace = grace
        e.jbuffer = jbuffer
        e.djump = djump
        e.dashTime = dashTime
        e.dashEffectTime = dashEffectTime
        e.dashTarget = dashTarget
        e.dashAccel = dashAccel
        e.sprOff = sprOff
        e.wasOnGround = wasOnGround
        e.hair = hair
        e.state = state
        e.delay = delay
        e.target = target
        e.hideIn = hideIn
        e.hideFor = hideFor
        e.timer = timer
        e.offset = offset
        e.start = start
        e.off = off
        e.fly = fly
        e.step = step
        e.sfxDelay = sfxDelay
        e.duration = duration
        e.flash = flash
        e.last = last
        e.dir = dir
        e.text = text
        e.index = index
        e.off2 = off2
        e.particles = particles
        e.particleCount = particleCount
        e.score = score
        e.show = show
        return e
    }
}
