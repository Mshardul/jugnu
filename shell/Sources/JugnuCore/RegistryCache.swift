import Foundation

public enum RegistryFetchResult: Equatable {
    case fresh([RegistryEntry])
    case cached([RegistryEntry])
    case unavailable
}

extension RegistryClient {
    public func fetchWithCache(from url: URL, cacheFile: URL) async -> RegistryFetchResult {
        if let entries = try? await fetch(from: url) {
            if let data = try? JSONEncoder().encode(entries) {
                try? FileManager.default.createDirectory(
                    at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try? data.write(to: cacheFile)
            }
            return .fresh(entries)
        }
        if let cachedData = try? Data(contentsOf: cacheFile),
           let cachedEntries = try? JSONDecoder().decode([RegistryEntry].self, from: cachedData) {
            return .cached(cachedEntries)
        }
        return .unavailable
    }
}
