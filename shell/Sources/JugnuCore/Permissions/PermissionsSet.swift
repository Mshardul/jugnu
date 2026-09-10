import Foundation

public enum PermissionsSet {
    public static func parse(_ raw: [String]) throws -> [AddonPermission] {
        var seen = Set<AddonPermission>()
        var parsed: [AddonPermission] = []
        for token in raw {
            guard let permission = AddonPermission(rawValue: token) else {
                throw PermissionsParseError.unknown(token)
            }
            if seen.insert(permission).inserted {
                parsed.append(permission)
            }
        }
        return sort(parsed)
    }

    public static func grew(from old: [AddonPermission], to new: [AddonPermission]) -> [AddonPermission] {
        let oldSet = Set(old)
        return sort(new.filter { !oldSet.contains($0) })
    }

    public static func needsLine(_ permissions: [AddonPermission]) -> String? {
        let ordered = sort(permissions)
        guard !ordered.isEmpty else { return nil }
        return "Needs " + ordered.map(\.displayTitle).joined(separator: ", ")
    }

    public static func unionExpand(
        addons: [(name: String, permissions: [AddonPermission])]
    ) -> [(permission: AddonPermission, addonNames: [String])] {
        var namesByPermission: [AddonPermission: Set<String>] = [:]
        for addon in addons {
            for permission in addon.permissions {
                namesByPermission[permission, default: []].insert(addon.name)
            }
        }
        return AddonPermission.displayOrder.compactMap { permission in
            guard let names = namesByPermission[permission], !names.isEmpty else { return nil }
            return (permission: permission, addonNames: names.sorted())
        }
    }

    public static func sort(_ permissions: [AddonPermission]) -> [AddonPermission] {
        let set = Set(permissions)
        return AddonPermission.displayOrder.filter { set.contains($0) }
    }
}
