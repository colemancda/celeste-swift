// Entity type table. Ported from the OBJ_PROP_LIST() X-macro in celeste.c.
// In the original, each type declares whether it has an init/update/draw
// callback, which map tile spawns it, and whether it should be skipped once
// its room's fruit has already been collected.

public enum ObjType: Int, CaseIterable {
    case player
    case playerSpawn
    case spring
    case balloon
    case smoke
    case platform
    case fallFloor
    case fruit
    case flyFruit
    case fakeWall
    case key
    case chest
    case lifeup
    case message
    case bigChest
    case orb
    case flag
    case roomTitle
}

struct ObjTypeInfo {
    let tile: Int
    let hasInit: Bool
    let hasUpdate: Bool
    let hasDraw: Bool
    let ifNotFruit: Bool
}

enum ObjTypeTable {
    //             TYPE           TILE  INIT   UPDATE DRAW   IF_NOT_FRUIT
    static let info: [ObjType: ObjTypeInfo] = [
        .player:      ObjTypeInfo(tile: -1,  hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: false),
        .playerSpawn: ObjTypeInfo(tile: 1,   hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: false),
        .spring:      ObjTypeInfo(tile: 18,  hasInit: true,  hasUpdate: true,  hasDraw: false, ifNotFruit: false),
        .balloon:     ObjTypeInfo(tile: 22,  hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: false),
        .smoke:       ObjTypeInfo(tile: -1,  hasInit: true,  hasUpdate: true,  hasDraw: false, ifNotFruit: false),
        .platform:    ObjTypeInfo(tile: -1,  hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: false),
        .fallFloor:   ObjTypeInfo(tile: 23,  hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: false),
        .fruit:       ObjTypeInfo(tile: 26,  hasInit: true,  hasUpdate: true,  hasDraw: false, ifNotFruit: true),
        .flyFruit:    ObjTypeInfo(tile: 28,  hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: true),
        .fakeWall:    ObjTypeInfo(tile: 64,  hasInit: false, hasUpdate: true,  hasDraw: true,  ifNotFruit: true),
        .key:         ObjTypeInfo(tile: 8,   hasInit: false, hasUpdate: true,  hasDraw: false, ifNotFruit: true),
        .chest:       ObjTypeInfo(tile: 20,  hasInit: true,  hasUpdate: true,  hasDraw: false, ifNotFruit: true),
        .lifeup:      ObjTypeInfo(tile: -1,  hasInit: true,  hasUpdate: true,  hasDraw: true,  ifNotFruit: false),
        .message:     ObjTypeInfo(tile: 86,  hasInit: false, hasUpdate: false, hasDraw: true,  ifNotFruit: false),
        .bigChest:    ObjTypeInfo(tile: 96,  hasInit: true,  hasUpdate: false, hasDraw: true,  ifNotFruit: false),
        .orb:         ObjTypeInfo(tile: -1,  hasInit: true,  hasUpdate: false, hasDraw: true,  ifNotFruit: false),
        .flag:        ObjTypeInfo(tile: 118, hasInit: true,  hasUpdate: false, hasDraw: true,  ifNotFruit: false),
        .roomTitle:   ObjTypeInfo(tile: -1,  hasInit: true,  hasUpdate: false, hasDraw: true,  ifNotFruit: false),
    ]

    static func tileType(forTile tile: Int) -> ObjType? {
        for type in ObjType.allCases {
            if info[type]!.tile == tile { return type }
        }
        return nil
    }
}
