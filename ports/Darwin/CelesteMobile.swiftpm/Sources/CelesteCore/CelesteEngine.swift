// CelesteEngine is a line-by-line port of celeste.c (itself a port of the
// original Celeste Classic PICO-8 cart by Matt Thorson & Noel Berry). It owns
// all gameplay state and drives it through `start()` / `update()` / `draw()`;
// a host port supplies a `CelesteRenderer` + `CelesteAudio` implementation and
// pumps `input` once per frame.
import Foundation

public final class CelesteEngine {
    public static let maxObjects = 30
    public static let fruitCount = 30

    public let renderer: CelesteRenderer
    public let audio: CelesteAudio
    public var input = CelesteInputState()

    private var rng = Pico8RNG()

    // globals ported from celeste.c
    private var room = VecI(x: 0, y: 0)
    private var freeze = 0
    private var shake = 0
    private var willRestart = false
    private var delayRestart = 0
    private var gotFruit = [Bool](repeating: false, count: CelesteEngine.fruitCount)
    private var hasDashed = false
    private var sfxTimer = 0
    private var hasKey = false
    private var pausePlayer = false
    private var flashBg = false
    private var musicTimer = 0

    private var newBg = false
    private var frames = 0
    private var seconds = 0
    private var minutes = 0
    private var deaths = 0
    private var maxDjump = 1
    private var startGame = false
    private var startGameFlash = 0

    private var clouds: [Cloud] = []
    private var particles = [Particle](repeating: Particle(), count: 25)
    private var deadParticles = [Particle](repeating: Particle(), count: 8)

    private var objects: [Entity] = (0..<CelesteEngine.maxObjects).map { _ in Entity() }
    private var nextObjectId: Int = 0
    private var roomJustLoaded = false

    public init(renderer: CelesteRenderer, audio: CelesteAudio, seed: UInt32 = 0) {
        self.renderer = renderer
        self.audio = audio
        rng.seed(seed == 0 ? 0 : seed)
    }

    public func setRandomSeed(_ seed: UInt32) {
        rng.seed(seed)
    }

    // MARK: - PICO-8 emu helpers

    private func p8rnd(_ max: Float) -> Float {
        let n = rng.random(Int32(max * Float(1 << 16)))
        return Float(n) / Float(1 << 16)
    }

    private func p8flr(_ v: Float) -> Float { v.rounded(.down) }

    // MARK: - entry point

    public func start() {
        prelude()
        titleScreen()
    }

    private func prelude() {
        preludeInitClouds()
        preludeInitParticles()
    }

    private func titleScreen() {
        for i in 0..<CelesteEngine.fruitCount { gotFruit[i] = false }
        frames = 0
        deaths = 0
        maxDjump = 1
        startGame = false
        startGameFlash = 0
        audio.music(index: 40, fadeMs: 0)
        loadRoom(x: 7, y: 3)
    }

    private func beginGame() {
        frames = 0
        seconds = 0
        minutes = 0
        musicTimer = 0
        startGame = false
        audio.music(index: 0, fadeMs: 0)
        loadRoom(x: 0, y: 0)
    }

    private func levelIndex() -> Int {
        room.x % 8 + room.y * 8
    }

    private func isTitle() -> Bool {
        levelIndex() == 31
    }

    // MARK: - effects

    private func preludeInitClouds() {
        clouds = (0...16).map { _ in
            Cloud(x: p8rnd(128), y: p8rnd(128), spd: 1 + p8rnd(4), w: 32 + p8rnd(32))
        }
    }

    private func preludeInitParticles() {
        for i in 0...24 {
            particles[i] = Particle(
                active: false,
                x: p8rnd(128), y: p8rnd(128),
                s: 0 + p8flr(p8rnd(5) / 4),
                spd: 0.25 + p8rnd(5),
                off: p8rnd(1),
                c: 6 + p8flr(0.5 + p8rnd(1))
            )
        }
    }

    // MARK: - object helpers (collision / movement)

    private func objIsSolid(_ obj: Entity, _ ox: Float, _ oy: Float) -> Bool {
        if oy > 0 && !objCheck(obj, .platform, ox, 0) && objCheck(obj, .platform, ox, oy) {
            return true
        }
        return solidAt(obj.x + Float(obj.hitbox.x) + ox, obj.y + Float(obj.hitbox.y) + oy, obj.hitbox.w, obj.hitbox.h)
            || objCheck(obj, .fallFloor, ox, oy)
            || objCheck(obj, .fakeWall, ox, oy)
    }

    private func objIsIce(_ obj: Entity, _ ox: Float, _ oy: Float) -> Bool {
        iceAt(obj.x + Float(obj.hitbox.x) + ox, obj.y + Float(obj.hitbox.y) + oy, obj.hitbox.w, obj.hitbox.h)
    }

    private func objCollide(_ obj: Entity, _ type: ObjType, _ ox: Float, _ oy: Float) -> Entity? {
        for other in objects {
            if other.active && other.type == type && other !== obj && other.collideable
                && other.x + Float(other.hitbox.x) + Float(other.hitbox.w) > obj.x + Float(obj.hitbox.x) + ox
                && other.y + Float(other.hitbox.y) + Float(other.hitbox.h) > obj.y + Float(obj.hitbox.y) + oy
                && other.x + Float(other.hitbox.x) < obj.x + Float(obj.hitbox.x) + Float(obj.hitbox.w) + ox
                && other.y + Float(other.hitbox.y) < obj.y + Float(obj.hitbox.y) + Float(obj.hitbox.h) + oy {
                return other
            }
        }
        return nil
    }

    private func objCheck(_ obj: Entity, _ type: ObjType, _ ox: Float, _ oy: Float) -> Bool {
        objCollide(obj, type, ox, oy) != nil
    }

    private func objMove(_ obj: Entity, _ ox: Float, _ oy: Float) {
        obj.rem.x += ox
        var amount = p8flr(obj.rem.x + 0.5)
        obj.rem.x -= amount
        objMoveX(obj, amount, 0)

        obj.rem.y += oy
        amount = p8flr(obj.rem.y + 0.5)
        obj.rem.y -= amount
        objMoveY(obj, amount)
    }

    private func objMoveX(_ obj: Entity, _ amount: Float, _ start: Float) {
        if obj.solids {
            let step = PicoMath.sign(amount)
            var i = start
            while i <= abs(amount) {
                if !objIsSolid(obj, step, 0) {
                    obj.x += step
                } else {
                    obj.spd.x = 0
                    obj.rem.x = 0
                    break
                }
                i += 1
            }
        } else {
            obj.x += amount
        }
    }

    private func objMoveY(_ obj: Entity, _ amount: Float) {
        if obj.solids {
            let step = PicoMath.sign(amount)
            var i: Float = 0
            while i <= abs(amount) {
                if !objIsSolid(obj, 0, step) {
                    obj.y += step
                } else {
                    obj.spd.y = 0
                    obj.rem.y = 0
                    break
                }
                i += 1
            }
        } else {
            obj.y += amount
        }
    }

    // MARK: - player

    private func playerInit(_ this: Entity) {
        this.pJump = false
        this.pDash = false
        this.grace = 0
        this.jbuffer = 0
        this.djump = maxDjump
        this.dashTime = 0
        this.dashEffectTime = 0
        this.dashTarget = Vec(x: 0, y: 0)
        this.dashAccel = Vec(x: 0, y: 0)
        this.hitbox = HitBox(x: 1, y: 3, w: 6, h: 5)
        this.sprOff = 0
        this.wasOnGround = false
        createHair(this)
    }

    private func playerUpdate(_ this0: Entity) {
        if pausePlayer { return }

        var this = this0
        let input = self.input.isDown(.right) ? 1 : (self.input.isDown(.left) ? -1 : 0)

        var doKillPlayer = false

        if spikesAt(this.x + Float(this.hitbox.x), this.y + Float(this.hitbox.y), this.hitbox.w, this.hitbox.h, this.spd.x, this.spd.y) {
            doKillPlayer = true
        }

        if this.y > 128 {
            doKillPlayer = true
        }
        if doKillPlayer {
            // simulate PICO-8 behavior of continuing to operate on a
            // dummy copy of the (now-destroyed) player object
            let dummy = this.copy()
            killPlayer(this)
            this = dummy
        }

        let onGround = objIsSolid(this, 0, 1)
        let onIce = objIsIce(this, 0, 1)

        if onGround && !this.wasOnGround {
            _ = initObject(.smoke, this.x, this.y + 4)
        }

        let jump = self.input.isDown(.jump) && !this.pJump
        this.pJump = self.input.isDown(.jump)
        if jump {
            this.jbuffer = 4
        } else if this.jbuffer > 0 {
            this.jbuffer -= 1
        }

        let dash = self.input.isDown(.dash) && !this.pDash
        this.pDash = self.input.isDown(.dash)

        if onGround {
            this.grace = 6
            if this.djump < maxDjump {
                psfx(54)
                this.djump = maxDjump
            }
        } else if this.grace > 0 {
            this.grace -= 1
        }

        this.dashEffectTime -= 1
        if this.dashTime > 0 {
            _ = initObject(.smoke, this.x, this.y)
            this.dashTime -= 1
            this.spd.x = PicoMath.appr(this.spd.x, this.dashTarget.x, this.dashAccel.x)
            this.spd.y = PicoMath.appr(this.spd.y, this.dashTarget.y, this.dashAccel.y)
        } else {
            let maxrun: Float = 1
            var accel: Float = 0.6
            let deccel: Float = 0.15

            if !onGround {
                accel = 0.4
            } else if onIce {
                accel = 0.05
                if Float(input) == (this.flipX ? -1 : 1) {
                    accel = 0.05
                }
            }

            if abs(this.spd.x) > maxrun {
                this.spd.x = PicoMath.appr(this.spd.x, PicoMath.sign(this.spd.x) * maxrun, deccel)
            } else {
                this.spd.x = PicoMath.appr(this.spd.x, Float(input) * maxrun, accel)
            }

            if this.spd.x != 0 {
                this.flipX = this.spd.x < 0
            }

            var maxfall: Float = 2
            var gravity: Float = 0.21

            if abs(this.spd.y) <= 0.15 {
                gravity *= 0.5
            }

            if input != 0 && objIsSolid(this, Float(input), 0) && !objIsIce(this, Float(input), 0) {
                maxfall = 0.4
                if p8rnd(10) < 2 {
                    _ = initObject(.smoke, this.x + Float(input) * 6, this.y)
                }
            }

            if !onGround {
                this.spd.y = PicoMath.appr(this.spd.y, maxfall, gravity)
            }

            if this.jbuffer > 0 {
                if this.grace > 0 {
                    psfx(1)
                    this.jbuffer = 0
                    this.grace = 0
                    this.spd.y = -2
                    _ = initObject(.smoke, this.x, this.y + 4)
                } else {
                    let wallDir: Int = objIsSolid(this, -3, 0) ? -1 : (objIsSolid(this, 3, 0) ? 1 : 0)
                    if wallDir != 0 {
                        psfx(2)
                        this.jbuffer = 0
                        this.spd.y = -2
                        this.spd.x = Float(-wallDir) * (maxrun + 1)
                        if !objIsIce(this, Float(wallDir) * 3, 0) {
                            _ = initObject(.smoke, this.x + Float(wallDir) * 6, this.y)
                        }
                    }
                }
            }

            let dFull: Float = 5
            let dHalf: Float = dFull * 0.70710678118

            if this.djump > 0 && dash {
                _ = initObject(.smoke, this.x, this.y)
                this.djump -= 1
                this.dashTime = 4
                hasDashed = true
                this.dashEffectTime = 10
                let vInput: Int = self.input.isDown(.up) ? -1 : (self.input.isDown(.down) ? 1 : 0)
                if input != 0 {
                    if vInput != 0 {
                        this.spd.x = Float(input) * dHalf
                        this.spd.y = Float(vInput) * dHalf
                    } else {
                        this.spd.x = Float(input) * dFull
                        this.spd.y = 0
                    }
                } else if vInput != 0 {
                    this.spd.x = 0
                    this.spd.y = Float(vInput) * dFull
                } else {
                    this.spd.x = this.flipX ? -1 : 1
                    this.spd.y = 0
                }

                psfx(3)
                freeze = 2
                shake = 6
                this.dashTarget.x = 2 * PicoMath.sign(this.spd.x)
                this.dashTarget.y = 2 * PicoMath.sign(this.spd.y)
                this.dashAccel.x = 1.5
                this.dashAccel.y = 1.5

                if this.spd.y < 0 {
                    this.dashTarget.y *= 0.75
                }

                if this.spd.y != 0 {
                    this.dashAccel.x *= 0.70710678118
                }
                if this.spd.x != 0 {
                    this.dashAccel.y *= 0.70710678118
                }
            } else if dash && this.djump <= 0 {
                psfx(9)
                _ = initObject(.smoke, this.x, this.y)
            }
        }

        this.sprOff += 0.25
        if !onGround {
            if objIsSolid(this, Float(input), 0) {
                this.spr = 5
            } else {
                this.spr = 3
            }
        } else if self.input.isDown(.down) {
            this.spr = 6
        } else if self.input.isDown(.up) {
            this.spr = 7
        } else if this.spd.x == 0 || (!self.input.isDown(.left) && !self.input.isDown(.right)) {
            this.spr = 1
        } else {
            this.spr = 1 + Float(Int(this.sprOff) % 4)
        }

        if this.y < -4 && levelIndex() < 30 { nextRoom() }

        this.wasOnGround = onGround
    }

    private func playerDraw(_ this: Entity) {
        if this.x < -1 || this.x > 121 {
            this.x = PicoMath.clamp(this.x, -1, 121)
            this.spd.x = 0
        }

        setHairColor(this.djump)
        drawHair(this, this.flipX ? -1 : 1)
        renderer.spr(Int(this.spr), x: this.x, y: this.y, flipX: this.flipX, flipY: this.flipY)
        unsetHairColor()
    }

    private func psfx(_ num: Int) {
        if sfxTimer <= 0 {
            audio.sfx(num)
        }
    }

    private func createHair(_ obj: Entity) {
        for i in 0...4 {
            obj.hair[i] = Hair(x: obj.x, y: obj.y, size: max(1, min(2, 3 - Float(i))), isLast: i == 4)
        }
    }

    private func setHairColor(_ djump: Int) {
        let b = djump == 1 ? 8 : (djump == 2 ? (7 + Int(p8flr(Float(frames) / 3.0)) % 2 * 4) : 12)
        renderer.pal(8, b)
    }

    private func drawHair(_ obj: Entity, _ facing: Int) {
        var lastX = obj.x + 4 - Float(facing) * 2
        var lastY = obj.y + (self.input.isDown(.down) ? 4 : 3)
        var i = 0
        while true {
            obj.hair[i].x += (lastX - obj.hair[i].x) / 1.5
            obj.hair[i].y += (lastY + 0.5 - obj.hair[i].y) / 1.5
            renderer.circfill(x: obj.hair[i].x, y: obj.hair[i].y, r: obj.hair[i].size, color: 8)
            lastX = obj.hair[i].x
            lastY = obj.hair[i].y
            let isLast = obj.hair[i].isLast
            i += 1
            if isLast { break }
        }
    }

    private func unsetHairColor() {
        renderer.pal(8, 8)
    }

    // MARK: - player_spawn

    private func playerSpawnInit(_ this: Entity) {
        audio.sfx(4)
        this.spr = 3
        this.target.x = this.x
        this.target.y = this.y
        this.y = 128
        this.spd.y = -4
        this.state = 0
        this.delay = 0
        this.solids = false
        createHair(this)
    }

    private func playerSpawnUpdate(_ this: Entity) {
        if this.state == 0 {
            if this.y < this.target.y + 16 {
                this.state = 1
                this.delay = 3
            }
        } else if this.state == 1 {
            this.spd.y += 0.5
            if this.spd.y > 0 && this.delay > 0 {
                this.spd.y = 0
                this.delay -= 1
            }
            if this.spd.y > 0 && this.y > this.target.y {
                this.y = this.target.y
                this.spd.x = 0
                this.spd.y = 0
                this.state = 2
                this.delay = 5
                shake = 5
                _ = initObject(.smoke, this.x, this.y + 4)
                audio.sfx(5)
            }
        } else if this.state == 2 {
            this.delay -= 1
            this.spr = 6
            if this.delay < 0 {
                let x = this.x, y = this.y
                destroyObject(this)
                _ = initObject(.player, x, y)
            }
        }
    }

    private func playerSpawnDraw(_ this: Entity) {
        setHairColor(maxDjump)
        drawHair(this, 1)
        renderer.spr(Int(this.spr), x: this.x, y: this.y, flipX: this.flipX, flipY: this.flipY)
        unsetHairColor()
    }

    // MARK: - spring

    private func springInit(_ this: Entity) {
        this.hideIn = 0
        this.hideFor = 0
    }

    private func springUpdate(_ this: Entity) {
        if this.hideFor > 0 {
            this.hideFor -= 1
            if this.hideFor <= 0 {
                this.spr = 18
                this.delay = 0
            }
        } else if this.spr == 18 {
            if let hit = objCollide(this, .player, 0, 0), hit.spd.y >= 0 {
                this.spr = 19
                hit.y = this.y - 4
                hit.spd.x *= 0.2
                hit.spd.y = -3
                hit.djump = maxDjump
                this.delay = 10
                _ = initObject(.smoke, this.x, this.y)

                if let below = objCollide(this, .fallFloor, 0, 1) {
                    breakFallFloor(below)
                }

                psfx(8)
            }
        } else if this.delay > 0 {
            this.delay -= 1
            if this.delay <= 0 {
                this.spr = 18
            }
        }
        if this.hideIn > 0 {
            this.hideIn -= 1
            if this.hideIn <= 0 {
                this.hideFor = 60
                this.spr = 0
            }
        }
    }

    private func breakSpring(_ obj: Entity) {
        obj.hideIn = 15
    }

    // MARK: - balloon

    private func balloonInit(_ this: Entity) {
        this.offset = p8rnd(1)
        this.start = this.y
        this.timer = 0
        this.hitbox = HitBox(x: -1, y: -1, w: 10, h: 10)
    }

    private func balloonUpdate(_ this: Entity) {
        if this.spr == 22 {
            this.offset += 0.01
            #if CELESTE_P8_HACKED_BALLOONS
            this.hitbox = HitBox(x: -1, y: -3, w: 10, h: 14)
            #else
            this.y = this.start + PicoMath.sin(this.offset) * 2
            #endif
            if let hit = objCollide(this, .player, 0, 0), hit.djump < maxDjump {
                psfx(6)
                _ = initObject(.smoke, this.x, this.y)
                hit.djump = maxDjump
                this.spr = 0
                this.timer = 60
            }
        } else if this.timer > 0 {
            this.timer -= 1
        } else {
            psfx(7)
            _ = initObject(.smoke, this.x, this.y)
            this.spr = 22
        }
    }

    private func balloonDraw(_ this: Entity) {
        if this.spr == 22 {
            renderer.spr(13 + Int(this.offset * 8) % 3, x: this.x, y: this.y + 6, flipX: false, flipY: false)
            renderer.spr(Int(this.spr), x: this.x, y: this.y, flipX: false, flipY: false)
        }
    }

    // MARK: - fall_floor

    private func fallFloorInit(_ this: Entity) {
        this.state = 0
    }

    private func fallFloorUpdate(_ this: Entity) {
        if this.state == 0 {
            if objCheck(this, .player, 0, -1) || objCheck(this, .player, -1, 0) || objCheck(this, .player, 1, 0) {
                breakFallFloor(this)
            }
        } else if this.state == 1 {
            this.delay -= 1
            if this.delay <= 0 {
                this.state = 2
                this.delay = 60
                this.collideable = false
            }
        } else if this.state == 2 {
            this.delay -= 1
            if this.delay <= 0 && !objCheck(this, .player, 0, 0) {
                psfx(7)
                this.state = 0
                this.collideable = true
                _ = initObject(.smoke, this.x, this.y)
            }
        }
    }

    private func fallFloorDraw(_ this: Entity) {
        if this.state != 2 {
            if this.state != 1 {
                renderer.spr(23, x: this.x, y: this.y, flipX: false, flipY: false)
            } else {
                renderer.spr(23 + (15 - this.delay) / 5, x: this.x, y: this.y, flipX: false, flipY: false)
            }
        }
    }

    private func breakFallFloor(_ obj: Entity) {
        if obj.state == 0 {
            psfx(15)
            obj.state = 1
            obj.delay = 15
            _ = initObject(.smoke, obj.x, obj.y)
            if let hit = objCollide(obj, .spring, 0, -1) {
                breakSpring(hit)
            }
        }
    }

    // MARK: - smoke

    private func smokeInit(_ this: Entity) {
        this.spr = 29
        this.spd.y = -0.1
        this.spd.x = 0.3 + p8rnd(0.2)
        this.x += -1 + p8rnd(2)
        this.y += -1 + p8rnd(2)
        this.flipX = maybe()
        this.flipY = maybe()
        this.solids = false
    }

    private func smokeUpdate(_ this: Entity) {
        this.spr += 0.2
        if this.spr >= 32 {
            destroyObject(this)
        }
    }

    // MARK: - fruit

    private func fruitInit(_ this: Entity) {
        this.start = this.y
        this.off = 0
    }

    private func fruitUpdate(_ this: Entity) {
        if let hit = objCollide(this, .player, 0, 0) {
            hit.djump = maxDjump
            sfxTimer = 20
            audio.sfx(13)
            gotFruit[levelIndex()] = true
            _ = initObject(.lifeup, this.x, this.y)
            destroyObject(this)
            return
        }
        this.off += 1
        this.y = this.start + PicoMath.sin(this.off / 40) * 2.5
    }

    // MARK: - fly_fruit

    private func flyFruitInit(_ this: Entity) {
        this.start = this.y
        this.fly = false
        this.step = 0.5
        this.solids = false
        this.sfxDelay = 8
    }

    private func flyFruitUpdate(_ this: Entity) {
        var doDestroy = false
        if this.fly {
            if this.sfxDelay > 0 {
                this.sfxDelay -= 1
                if this.sfxDelay <= 0 {
                    sfxTimer = 20
                    audio.sfx(14)
                }
            }
            this.spd.y = PicoMath.appr(this.spd.y, -3.5, 0.25)
            if this.y < -16 {
                doDestroy = true
            }
        } else {
            if hasDashed {
                this.fly = true
            }
            this.step += 0.05
            this.spd.y = PicoMath.sin(this.step) * 0.5
        }
        if let hit = objCollide(this, .player, 0, 0) {
            hit.djump = maxDjump
            sfxTimer = 20
            audio.sfx(13)
            gotFruit[levelIndex()] = true
            _ = initObject(.lifeup, this.x, this.y)
            doDestroy = true
        }
        if doDestroy { destroyObject(this) }
    }

    private func flyFruitDraw(_ this: Entity) {
        var off: Float = 0
        if !this.fly {
            let dir = PicoMath.sin(this.step)
            if dir < 0 {
                off = 1 + max(0, PicoMath.sign(this.y - this.start))
            }
        } else {
            off = PicoMath.modulo(off + 0.25, 3)
        }
        renderer.spr(45 + Int(off), x: this.x - 6, y: this.y - 2, flipX: true, flipY: false)
        renderer.spr(Int(this.spr), x: this.x, y: this.y, flipX: false, flipY: false)
        renderer.spr(45 + Int(off), x: this.x + 6, y: this.y - 2, flipX: false, flipY: false)
    }

    // MARK: - lifeup

    private func lifeupInit(_ this: Entity) {
        this.spd.y = -0.25
        this.duration = 30
        this.x -= 2
        this.y -= 4
        this.flash = 0
        this.solids = false
    }

    private func lifeupUpdate(_ this: Entity) {
        this.duration -= 1
        if this.duration <= 0 {
            destroyObject(this)
        }
    }

    private func lifeupDraw(_ this: Entity) {
        this.flash += 0.5
        renderer.print("1000", x: this.x - 2, y: this.y, color: 7 + Int(this.flash) % 2)
    }

    // MARK: - fake_wall

    private func fakeWallUpdate(_ this: Entity) {
        this.hitbox = HitBox(x: -1, y: -1, w: 18, h: 18)
        if let hit = objCollide(this, .player, 0, 0), hit.dashEffectTime > 0 {
            hit.spd.x = -PicoMath.sign(hit.spd.x) * 1.5
            hit.spd.y = -1.5
            hit.dashTime = -1
            sfxTimer = 20
            audio.sfx(16)
            _ = initObject(.smoke, this.x, this.y)
            _ = initObject(.smoke, this.x + 8, this.y)
            _ = initObject(.smoke, this.x, this.y + 8)
            _ = initObject(.smoke, this.x + 8, this.y + 8)
            _ = initObject(.fruit, this.x + 4, this.y + 4)
            destroyObject(this)
            return
        }
        this.hitbox = HitBox(x: 0, y: 0, w: 16, h: 16)
    }

    private func fakeWallDraw(_ this: Entity) {
        renderer.spr(64, x: this.x, y: this.y, flipX: false, flipY: false)
        renderer.spr(65, x: this.x + 8, y: this.y, flipX: false, flipY: false)
        renderer.spr(80, x: this.x, y: this.y + 8, flipX: false, flipY: false)
        renderer.spr(81, x: this.x + 8, y: this.y + 8, flipX: false, flipY: false)
    }

    // MARK: - key

    private func keyUpdate(_ this: Entity) {
        let was = Int(p8flr(this.spr))
        this.spr = 9 + (PicoMath.sin(Float(frames) / 30.0) + 0.5) * 1
        let isNow = Int(p8flr(this.spr))
        if isNow == 10 && isNow != was {
            this.flipX.toggle()
        }
        if objCheck(this, .player, 0, 0) {
            audio.sfx(23)
            sfxTimer = 10
            destroyObject(this)
            hasKey = true
        }
    }

    // MARK: - chest

    private func chestInit(_ this: Entity) {
        this.x -= 4
        this.start = this.x
        this.timer = 20
    }

    private func chestUpdate(_ this: Entity) {
        if hasKey {
            this.timer -= 1
            this.x = this.start - 1 + p8rnd(3)
            if this.timer <= 0 {
                sfxTimer = 20
                audio.sfx(16)
                _ = initObject(.fruit, this.x, this.y - 4)
                destroyObject(this)
            }
        }
    }

    // MARK: - platform

    private func platformInit(_ this: Entity) {
        this.x -= 4
        this.solids = false
        this.hitbox.w = 16
        this.last = this.x
    }

    private func platformUpdate(_ this: Entity) {
        this.spd.x = this.dir * 0.65
        if this.x < -16 { this.x = 128 }
        else if this.x > 128 { this.x = -16 }
        if !objCheck(this, .player, 0, 0) {
            if let hit = objCollide(this, .player, 0, -1) {
                objMoveX(hit, this.x - this.last, 1)
            }
        }
        this.last = this.x
    }

    private func platformDraw(_ this: Entity) {
        renderer.spr(11, x: this.x, y: this.y - 1, flipX: false, flipY: false)
        renderer.spr(12, x: this.x + 8, y: this.y - 1, flipX: false, flipY: false)
    }

    // MARK: - message

    private func messageDraw(_ this: Entity) {
        this.text = "-- celeste mountain --#this memorial to those# perished on the climb"
        if objCheck(this, .player, 4, 0) {
            let chars = Array(this.text)
            if this.index < Float(chars.count) {
                this.index += 0.5
                if this.index >= this.last + 1 {
                    this.last += 1
                    audio.sfx(35)
                }
            }
            this.off2.x = 8
            this.off2.y = 96
            var i = 0
            while Float(i) < this.index {
                if chars[i] != "#" {
                    renderer.rectfill(x0: Float(this.off2.x - 2), y0: Float(this.off2.y - 2), x1: Float(this.off2.x + 7), y1: Float(this.off2.y + 6), color: 7)
                    renderer.print(String(chars[i]), x: Float(this.off2.x), y: Float(this.off2.y), color: 0)
                    this.off2.x += 5
                } else {
                    this.off2.x = 8
                    this.off2.y += 7
                }
                i += 1
            }
        } else {
            this.index = 0
            this.last = 0
        }
    }

    // MARK: - big_chest

    private func bigChestInit(_ this: Entity) {
        this.state = 0
        this.hitbox.w = 16
    }

    private func bigChestDraw(_ this: Entity) {
        if this.state == 0 {
            if let hit = objCollide(this, .player, 0, 8), objIsSolid(hit, 0, 1) {
                audio.music(index: -1, fadeMs: 500)
                audio.sfx(37)
                pausePlayer = true
                hit.spd.x = 0
                hit.spd.y = 0
                this.state = 1
                _ = initObject(.smoke, this.x, this.y)
                _ = initObject(.smoke, this.x + 8, this.y)
                this.timer = 60
                this.particleCount = 0
            }
            renderer.spr(96, x: this.x, y: this.y, flipX: false, flipY: false)
            renderer.spr(97, x: this.x + 8, y: this.y, flipX: false, flipY: false)
        } else if this.state == 1 {
            this.timer -= 1
            shake = 5
            flashBg = true
            if this.timer <= 45 && this.particleCount < 50 {
                this.particles[this.particleCount] = Particle(x: 1 + p8rnd(14), y: 0, spd: 8 + p8rnd(8), h: 32 + p8rnd(32))
                this.particleCount += 1
            }
            if this.timer < 0 {
                this.state = 2
                this.particleCount = 0
                flashBg = false
                newBg = true
                _ = initObject(.orb, this.x + 4, this.y + 4)
                pausePlayer = false
            }
            for i in 0..<this.particleCount {
                this.particles[i].y += this.particles[i].spd
                let p = this.particles[i]
                renderer.line(x0: this.x + p.x, y0: this.y + 8 - p.y, x1: this.x + p.x, y1: min(this.y + 8 - p.y + p.h, this.y + 8), color: 7)
            }
        }
        renderer.spr(112, x: this.x, y: this.y + 8, flipX: false, flipY: false)
        renderer.spr(113, x: this.x + 8, y: this.y + 8, flipX: false, flipY: false)
    }

    // MARK: - orb

    private func orbInit(_ this: Entity) {
        this.spd.y = -4
        this.solids = false
        this.particleCount = 0
    }

    private func orbDraw(_ this: Entity) {
        this.spd.y = PicoMath.appr(this.spd.y, 0, 0.5)
        let hit = objCollide(this, .player, 0, 0)
        var destroySelf = false
        if this.spd.y == 0, let hit {
            musicTimer = 45
            audio.sfx(51)
            freeze = 10
            shake = 10
            destroySelf = true
            maxDjump = 2
            hit.djump = 2
        }

        renderer.spr(102, x: this.x, y: this.y, flipX: false, flipY: false)
        let off = Float(frames) / 30.0
        var i: Float = 0
        while i <= 7 {
            renderer.circfill(x: this.x + 4 + PicoMath.cos(off + i / 8.0) * 8, y: this.y + 4 + PicoMath.sin(off + i / 8.0) * 8, r: 1, color: 7)
            i += 1
        }
        if destroySelf { destroyObject(this) }
    }

    // MARK: - flag

    private func flagInit(_ this: Entity) {
        this.x += 5
        this.score = 0
        this.show = false
        for i in 0..<CelesteEngine.fruitCount {
            if gotFruit[i] { this.score += 1 }
        }
    }

    private func flagDraw(_ this: Entity) {
        this.spr = 118 + PicoMath.modulo(Float(frames) / 5.0, 3)
        renderer.spr(Int(this.spr), x: this.x, y: this.y, flipX: false, flipY: false)
        if this.show {
            renderer.rectfill(x0: 32, y0: 2, x1: 96, y1: 31, color: 0)
            renderer.spr(26, x: 55, y: 6, flipX: false, flipY: false)
            renderer.print("x\(this.score)", x: 64, y: 9, color: 7)
            drawTime(49, 16)
            renderer.print("deaths:\(deaths)", x: 48, y: 24, color: 7)
        } else if objCheck(this, .player, 0, 0) {
            audio.sfx(55)
            sfxTimer = 30
            this.show = true
        }
    }

    // MARK: - room_title

    private func roomTitleInit(_ this: Entity) {
        this.delay = 5
    }

    private func roomTitleDraw(_ this: Entity) {
        this.delay -= 1
        if this.delay < -30 {
            destroyObject(this)
        } else if this.delay < 0 {
            renderer.rectfill(x0: 24, y0: 58, x1: 104, y1: 70, color: 0)
            if room.x == 3 && room.y == 1 {
                renderer.print("old site", x: 48, y: 62, color: 7)
            } else if levelIndex() == 30 {
                renderer.print("summit", x: 52, y: 62, color: 7)
            } else {
                let level = (1 + levelIndex()) * 100
                renderer.print("\(level) m", x: 52 + (level < 1000 ? 2 : 0), y: 62, color: 7)
            }
            drawTime(4, 4)
        }
    }

    // MARK: - object management

    private func initObject(_ type: ObjType, _ x: Float, _ y: Float) -> Entity? {
        let info = ObjTypeTable.info[type]!
        if info.ifNotFruit && gotFruit[levelIndex()] {
            return nil
        }
        guard let obj = objects.first(where: { !$0.active }) else {
            print("exhausted object memory..")
            return nil
        }

        obj.active = true
        obj.id = nextObjectId
        nextObjectId += 1

        obj.type = type
        obj.collideable = true
        obj.solids = true

        obj.spr = Float(info.tile)
        obj.flipX = false
        obj.flipY = false

        obj.x = x
        obj.y = y
        obj.hitbox = HitBox(x: 0, y: 0, w: 8, h: 8)

        obj.spd = Vec(x: 0, y: 0)
        obj.rem = Vec(x: 0, y: 0)

        callInit(type, obj)
        return obj
    }

    private func destroyObject(_ obj: Entity) {
        guard let idx = objects.firstIndex(where: { $0 === obj }) else { return }
        objects.remove(at: idx)
        objects.append(Entity())
    }

    private func killPlayer(_ obj: Entity) {
        sfxTimer = 12
        audio.sfx(0)
        deaths += 1
        shake = 10
        var dir: Float = 0
        while dir <= 7 {
            let angle = dir / 8
            deadParticles[Int(dir)] = Particle(
                active: true,
                x: obj.x + 4, y: obj.y + 4,
                t: 10,
                spd2: Vec(x: PicoMath.sin(angle) * 3, y: PicoMath.cos(angle) * 3)
            )
            restartRoom()
            dir += 1
        }
        destroyObject(obj)
    }

    // MARK: - room functions

    private func restartRoom() {
        willRestart = true
        delayRestart = 15
    }

    private func nextRoom() {
        if room.x == 2 && room.y == 1 {
            audio.music(index: 30, fadeMs: 500)
        } else if room.x == 3 && room.y == 1 {
            audio.music(index: 20, fadeMs: 500)
        } else if room.x == 4 && room.y == 2 {
            audio.music(index: 30, fadeMs: 500)
        } else if room.x == 5 && room.y == 3 {
            audio.music(index: 30, fadeMs: 500)
        }

        if room.x == 7 {
            loadRoom(x: 0, y: room.y + 1)
        } else {
            loadRoom(x: room.x + 1, y: room.y)
        }
    }

    private func loadRoom(x: Int, y: Int) {
        hasDashed = false
        hasKey = false
        roomJustLoaded = true

        for obj in objects { obj.active = false }

        room.x = x
        room.y = y

        for tx in 0...15 {
            for ty in 0...15 {
                let tile = Int(mget(room.x * 16 + tx, room.y * 16 + ty))
                if tile == 11 {
                    initObject(.platform, Float(tx * 8), Float(ty * 8))?.dir = -1
                } else if tile == 12 {
                    initObject(.platform, Float(tx * 8), Float(ty * 8))?.dir = 1
                } else if let type = ObjTypeTable.tileType(forTile: tile) {
                    _ = initObject(type, Float(tx * 8), Float(ty * 8))
                }
            }
        }

        if !isTitle() {
            _ = initObject(.roomTitle, 0, 0)
        }
    }

    // MARK: - update

    public func update() {
        frames = (frames + 1) % 30
        if frames == 0 && levelIndex() < 30 {
            seconds = (seconds + 1) % 60
            if seconds == 0 {
                minutes += 1
            }
        }

        if musicTimer > 0 {
            musicTimer -= 1
            if musicTimer <= 0 {
                audio.music(index: 10, fadeMs: 0)
            }
        }

        if sfxTimer > 0 {
            sfxTimer -= 1
        }

        if freeze > 0 { freeze -= 1; return }

        if shake > 0 {
            shake -= 1
            renderer.camera(x: 0, y: 0)
            if shake > 0 {
                renderer.camera(x: Int(-2 + p8rnd(5)), y: Int(-2 + p8rnd(5)))
            }
        }

        if willRestart && delayRestart > 0 {
            delayRestart -= 1
            if delayRestart <= 0 {
                willRestart = false
                loadRoom(x: room.x, y: room.y)
            }
        }

        roomJustLoaded = false
        var i = 0
        while i < objects.count {
            let obj = objects[i]
            if !obj.active { i += 1; continue }

            objMove(obj, obj.spd.x, obj.spd.y)
            let thisId = obj.id
            callUpdate(obj.type, obj)

            if roomJustLoaded { roomJustLoaded = false }

            // Replicates the goto redo_update_slot in celeste.c: if this
            // slot's identity changed underneath us (an object earlier in
            // the room was destroyed and slots shifted), re-run this index.
            if thisId != objects[i].id {
                continue
            }
            i += 1
        }

        if isTitle() {
            if !startGame && (input.isDown(.jump) || input.isDown(.dash)) {
                audio.music(index: -1, fadeMs: 0)
                startGameFlash = 50
                startGame = true
                audio.sfx(38)
            }
            if startGame {
                startGameFlash -= 1
                if startGameFlash <= -30 {
                    beginGame()
                }
            }
        }
    }

    // MARK: - draw

    public func draw() {
        if freeze > 0 { return }

        renderer.palReset()

        if startGame {
            var c = 10
            if startGameFlash > 10 {
                if frames % 10 < 5 { c = 7 }
            } else if startGameFlash > 5 {
                c = 2
            } else if startGameFlash > 0 {
                c = 1
            } else {
                c = 0
            }
            if c < 10 {
                renderer.pal(6, c)
                renderer.pal(12, c)
                renderer.pal(13, c)
                renderer.pal(5, c)
                renderer.pal(1, c)
                renderer.pal(7, c)
            }
        }

        var bgCol = 0
        if flashBg {
            bgCol = frames / 5
        } else if newBg {
            bgCol = 2
        }
        renderer.rectfill(x0: 0, y0: 0, x1: 128, y1: 128, color: bgCol)

        if !isTitle() {
            for i in 0...16 {
                clouds[i].x += clouds[i].spd
                renderer.rectfill(x0: clouds[i].x, y0: clouds[i].y, x1: clouds[i].x + clouds[i].w, y1: clouds[i].y + 4 + (1 - clouds[i].w / 64.0) * 12, color: newBg ? 14 : 1)
                if clouds[i].x > 128 {
                    clouds[i].x = -clouds[i].w
                    clouds[i].y = p8rnd(128 - 8)
                }
            }
        }

        drawMap(mx: room.x * 16, my: room.y * 16, tx: 0, ty: 0, mw: 16, mh: 16, mask: 4)

        for obj in objects where obj.active && (obj.type == .platform || obj.type == .bigChest) {
            drawObject(obj)
        }

        let off = isTitle() ? -4 : 0
        drawMap(mx: room.x * 16, my: room.y * 16, tx: off, ty: 0, mw: 16, mh: 16, mask: 2)

        for obj in objects where obj.active && obj.type != .platform && obj.type != .bigChest {
            drawObject(obj)
        }

        drawMap(mx: room.x * 16, my: room.y * 16, tx: 0, ty: 0, mw: 16, mh: 16, mask: 8)

        for i in 0...24 {
            particles[i].x += particles[i].spd
            particles[i].y += PicoMath.sin(particles[i].off)
            particles[i].off += min(0.05, particles[i].spd / 32)
            let p = particles[i]
            renderer.rectfill(x0: p.x, y0: p.y, x1: p.x + p.s, y1: p.y + p.s, color: Int(p.c))
            if particles[i].x > 128 + 4 {
                particles[i].x = -4
                particles[i].y = p8rnd(128)
            }
        }

        for i in 0...7 {
            if deadParticles[i].active {
                deadParticles[i].x += deadParticles[i].spd2.x
                deadParticles[i].y += deadParticles[i].spd2.y
                deadParticles[i].t -= 1
                if deadParticles[i].t <= 0 { deadParticles[i].active = false }
                let p = deadParticles[i]
                renderer.rectfill(x0: p.x - p.t / 5, y0: p.y - p.t / 5, x1: p.x + p.t / 5, y1: p.y + p.t / 5, color: Int(14 + PicoMath.modulo(p.t, 2)))
            }
        }

        renderer.rectfill(x0: -5, y0: -5, x1: -1, y1: 133, color: 0)
        renderer.rectfill(x0: -5, y0: -5, x1: 133, y1: -1, color: 0)
        renderer.rectfill(x0: -5, y0: 128, x1: 133, y1: 133, color: 0)
        renderer.rectfill(x0: 128, y0: -5, x1: 133, y1: 133, color: 0)

        if isTitle() {
            renderer.print("x+c", x: 58, y: 80, color: 5)
            renderer.print("matt thorson", x: 42, y: 96, color: 5)
            renderer.print("noel berry", x: 46, y: 102, color: 5)
        }

        if levelIndex() == 30 {
            if let p = objects.first(where: { $0.active && $0.type == .player }) {
                let diff = min(24, 40 - abs(p.x + 4 - 64))
                renderer.rectfill(x0: 0, y0: 0, x1: diff, y1: 128, color: 0)
                renderer.rectfill(x0: 128 - diff, y0: 0, x1: 128, y1: 128, color: 0)
            }
        }
    }

    private func drawObject(_ obj: Entity) {
        if !callDraw(obj.type, obj) && obj.spr > 0 {
            renderer.spr(Int(obj.spr), x: obj.x, y: obj.y, flipX: obj.flipX, flipY: obj.flipY)
        }
    }

    private func drawTime(_ x: Float, _ y: Float) {
        let s = seconds
        let m = minutes % 60
        let h = minutes / 60

        renderer.rectfill(x0: x, y0: y, x1: x + 32, y1: y + 6, color: 0)
        let str = String(format: "%.2d:%.2d:%.2d", h, m, s)
        renderer.print(str, x: x + 1, y: y + 1, color: 7)
    }

    // MARK: - entity type dispatch (replaces the OBJTYPE_prop function-pointer table)

    private func callInit(_ type: ObjType, _ obj: Entity) {
        switch type {
        case .player: playerInit(obj)
        case .playerSpawn: playerSpawnInit(obj)
        case .spring: springInit(obj)
        case .balloon: balloonInit(obj)
        case .smoke: smokeInit(obj)
        case .platform: platformInit(obj)
        case .fallFloor: fallFloorInit(obj)
        case .fruit: fruitInit(obj)
        case .flyFruit: flyFruitInit(obj)
        case .chest: chestInit(obj)
        case .lifeup: lifeupInit(obj)
        case .bigChest: bigChestInit(obj)
        case .orb: orbInit(obj)
        case .flag: flagInit(obj)
        case .roomTitle: roomTitleInit(obj)
        case .fakeWall, .key, .message:
            break // no init in original
        }
    }

    private func callUpdate(_ type: ObjType, _ obj: Entity) {
        switch type {
        case .player: playerUpdate(obj)
        case .playerSpawn: playerSpawnUpdate(obj)
        case .spring: springUpdate(obj)
        case .balloon: balloonUpdate(obj)
        case .smoke: smokeUpdate(obj)
        case .platform: platformUpdate(obj)
        case .fallFloor: fallFloorUpdate(obj)
        case .fruit: fruitUpdate(obj)
        case .flyFruit: flyFruitUpdate(obj)
        case .fakeWall: fakeWallUpdate(obj)
        case .key: keyUpdate(obj)
        case .chest: chestUpdate(obj)
        case .lifeup: lifeupUpdate(obj)
        case .message, .bigChest, .orb, .flag, .roomTitle:
            break // no update in original
        }
    }

    /// Returns true if the type has a custom draw function (mirrors
    /// OBJTYPE_prop[type].draw != NULL in draw_object()).
    @discardableResult
    private func callDraw(_ type: ObjType, _ obj: Entity) -> Bool {
        switch type {
        case .player: playerDraw(obj); return true
        case .playerSpawn: playerSpawnDraw(obj); return true
        case .balloon: balloonDraw(obj); return true
        case .platform: platformDraw(obj); return true
        case .fallFloor: fallFloorDraw(obj); return true
        case .flyFruit: flyFruitDraw(obj); return true
        case .fakeWall: fakeWallDraw(obj); return true
        case .lifeup: lifeupDraw(obj); return true
        case .message: messageDraw(obj); return true
        case .bigChest: bigChestDraw(obj); return true
        case .orb: orbDraw(obj); return true
        case .flag: flagDraw(obj); return true
        case .roomTitle: roomTitleDraw(obj); return true
        case .spring, .smoke, .fruit, .key, .chest:
            return false // no draw in original; falls back to default spr()
        }
    }

    // MARK: - helper functions

    private func maybe() -> Bool { p8rnd(1) < 0.5 }

    private func solidAt(_ x: Float, _ y: Float, _ w: Int, _ h: Int) -> Bool {
        tileFlagAt(x, y, w, h, 0)
    }

    private func iceAt(_ x: Float, _ y: Float, _ w: Int, _ h: Int) -> Bool {
        tileFlagAt(x, y, w, h, 4)
    }

    private func tileFlagAt(_ x: Float, _ y: Float, _ w: Int, _ h: Int, _ flag: Int) -> Bool {
        var i = Int(max(0, p8flr(x / 8)))
        let iMax = Int(min(15, floor((x + Float(w) - 1) / 8)))
        while i <= iMax {
            var j = Int(max(0, p8flr(y / 8)))
            let jMax = Int(min(15, floor((y + Float(h) - 1) / 8)))
            while j <= jMax {
                if fget(tileAt(i, j), flag) { return true }
                j += 1
            }
            i += 1
        }
        return false
    }

    private func tileAt(_ x: Int, _ y: Int) -> Int {
        Int(mget(room.x * 16 + x, room.y * 16 + y))
    }

    private func spikesAt(_ x: Float, _ y: Float, _ w: Int, _ h: Int, _ xspd: Float, _ yspd: Float) -> Bool {
        var i = Int(max(0, p8flr(x / 8)))
        let iMax = Int(min(15, floor((x + Float(w) - 1) / 8)))
        while i <= iMax {
            var j = Int(max(0, p8flr(y / 8)))
            let jMax = Int(min(15, floor((y + Float(h) - 1) / 8)))
            while j <= jMax {
                let tile = tileAt(i, j)
                if tile == 17 && (PicoMath.modulo(y + Float(h) - 1, 8) >= 6 || y + Float(h) == Float(j * 8 + 8)) && yspd >= 0 {
                    return true
                } else if tile == 27 && PicoMath.modulo(y, 8) <= 2 && yspd <= 0 {
                    return true
                } else if tile == 43 && PicoMath.modulo(x, 8) <= 2 && xspd <= 0 {
                    return true
                } else if tile == 59 && (PicoMath.modulo(x + Float(w) - 1, 8) >= 6 || x + Float(w) == Float(i * 8 + 8)) && xspd >= 0 {
                    return true
                }
                j += 1
            }
            i += 1
        }
        return false
    }

    // MARK: - tilemap access

    private func mget(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < 128, y < 64 else { return 0 }
        return tilemapData[x + y * 128]
    }

    private func fget(_ tile: Int, _ flag: Int) -> Bool {
        guard tile >= 0 && tile < tileFlags.count else { return false }
        return tileFlags[tile] & (1 << UInt8(flag)) != 0
    }

    private func drawMap(mx: Int, my: Int, tx: Int, ty: Int, mw: Int, mh: Int, mask: Int) {
        for x in 0..<mw {
            for y in 0..<mh {
                let tile = Int(mget(x + mx, y + my))
                let flagsByte = tile < tileFlags.count ? tileFlags[tile] : 0
                let matches = mask == 0
                    || (mask == 4 && flagsByte == 4)
                    || fget(tile, mask != 4 ? mask - 1 : mask)
                if matches {
                    renderer.spr(tile, x: Float(tx + x * 8), y: Float(ty + y * 8), flipX: false, flipY: false)
                }
            }
        }
    }
}
