import Foundation

public enum RegistryFetchFailure: Error, Equatable {
    case unreachable
    case invalid
}

public enum RegistryFetchResult: Equatable {
    case fresh([RegistryEntry])
    case cached([RegistryEntry], failure: RegistryFetchFailure)
    case unavailable(RegistryFetchFailure)
}

extension RegistryClient {
    public func fetchWithCache(from url: URL, cacheFile: URL) async -> RegistryFetchResult {
        do {
            let entries = try await fetch(from: url)
            if let data = try? JSONEncoder().encode(entries) {
                try? FileManager.default.createDirectory(
                    at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try? data.write(to: cacheFile)
            }
            return .fresh(entries)
        } catch {
            let failure: RegistryFetchFailure =
                (error as? RegistryClientError) == .invalidCatalog ? .invalid : .unreachable
            if let cachedData = try? Data(contentsOf: cacheFile),
               let cachedEntries = try? JSONDecoder().decode([RegistryEntry].self, from: cachedData) {
                return .cached(cachedEntries, failure: failure)
            }
            return .unavailable(failure)
        }
    }
}
