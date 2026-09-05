import Foundation

public enum ZoneSavePlan: Equatable, Sendable {
    case askName
    case pickReplacement([Zone])
    case commit(name: String, replacing: String?)
}

public enum ZoneSavePlanner {
    public static func plan(store: ZoneStore, name: String?, replaceId: String?) -> ZoneSavePlan {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = (trimmed?.isEmpty == false) ? trimmed : nil
        if store.isFull, replaceId == nil {
            return .pickReplacement(store.zones)
        }
        if let replaceId, named == nil, let existing = store.zone(id: replaceId) {
            return .commit(name: existing.name, replacing: replaceId)
        }
        if let named {
            return .commit(name: named, replacing: replaceId)
        }
        return .askName
    }
}
