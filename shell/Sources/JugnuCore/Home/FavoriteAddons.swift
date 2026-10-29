import Foundation

public func migrateFavoriteAddons(
    commandIDs: [String],
    owner: (String) -> String?
) -> [String] {
    var seen = Set<String>()
    var addons: [String] = []
    for commandID in commandIDs {
        guard let addonID = owner(commandID), seen.insert(addonID).inserted else { continue }
        addons.append(addonID)
    }
    return addons
}
