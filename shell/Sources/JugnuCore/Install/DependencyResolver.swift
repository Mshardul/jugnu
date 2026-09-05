import Foundation

/// Declared addon node for resolve (from registry and/or manifest).
public struct DeclaredAddon: Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var dependencies: [AddonDependency]

    public init(id: String, name: String, version: String, dependencies: [AddonDependency] = []) {
        self.id = id
        self.name = name
        self.version = version
        self.dependencies = dependencies
    }

    public init(entry: RegistryEntry) {
        self.id = entry.id
        self.name = entry.name
        self.version = entry.version
        self.dependencies = entry.dependencies
    }
}

public struct DependencyPlanItem: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case alreadyInstalled
        case willInstall
    }

    public var id: String
    public var name: String
    public var version: String
    public var status: Status

    public init(id: String, name: String, version: String, status: Status) {
        self.id = id
        self.name = name
        self.version = version
        self.status = status
    }
}

public struct DependencyPlan: Equatable, Sendable {
    public var primaryId: String
    public var primaryName: String
    /// Dependencies only (not the primary), disclosure order.
    public var dependencies: [DependencyPlanItem]
    /// Topological install order including primary last.
    public var installOrder: [String]

    public init(
        primaryId: String,
        primaryName: String,
        dependencies: [DependencyPlanItem],
        installOrder: [String]
    ) {
        self.primaryId = primaryId
        self.primaryName = primaryName
        self.dependencies = dependencies
        self.installOrder = installOrder
    }

    public var needsDisclosure: Bool { !dependencies.isEmpty }
}

public enum DependencyResolverError: Error, Equatable {
    case unknown(id: String)
    case cycle([String])
    case versionMismatch(id: String, required: String, installed: String)
    case collision(id: String, occupant: String)
    case invalidVersion(String)
}

public enum DependencyResolver {
    /// Plan install of `root` using `catalog` (must include root and every reachable dep id)
    /// and `installed` id→exact version currently on disk.
    public static func plan(
        root: DeclaredAddon,
        catalog: [String: DeclaredAddon],
        installed: [String: String]
    ) throws -> DependencyPlan {
        var nodes = catalog
        nodes[root.id] = root

        for dep in root.dependencies {
            guard PackageGates.isValidSemVer(dep.version) else {
                throw DependencyResolverError.invalidVersion(dep.version)
            }
        }

        try checkCollision(installing: root.id, installedIds: Array(installed.keys))

        var visiting = Set<String>()
        var visited = Set<String>()
        var order: [String] = []

        func visit(_ id: String) throws {
            if visited.contains(id) { return }
            if visiting.contains(id) {
                throw DependencyResolverError.cycle(Array(visiting) + [id])
            }
            visiting.insert(id)
            guard let node = nodes[id] else {
                throw DependencyResolverError.unknown(id: id)
            }
            for dep in node.dependencies {
                guard PackageGates.isValidSemVer(dep.version) else {
                    throw DependencyResolverError.invalidVersion(dep.version)
                }
                if let have = installed[dep.id] {
                    if have != dep.version {
                        throw DependencyResolverError.versionMismatch(
                            id: dep.id, required: dep.version, installed: have
                        )
                    }
                } else {
                    try checkCollision(installing: dep.id, installedIds: Array(installed.keys) + order)
                    guard let depNode = nodes[dep.id] else {
                        throw DependencyResolverError.unknown(id: dep.id)
                    }
                    if depNode.version != dep.version {
                        throw DependencyResolverError.versionMismatch(
                            id: dep.id, required: dep.version, installed: depNode.version
                        )
                    }
                    try visit(dep.id)
                }
            }
            visiting.remove(id)
            visited.insert(id)
            order.append(id)
        }

        try visit(root.id)

        // Ensure primary is last among packages we may install.
        var installOrder = order.filter { id in
            if id == root.id { return true }
            return installed[id] == nil
        }
        if let idx = installOrder.firstIndex(of: root.id) {
            installOrder.remove(at: idx)
            installOrder.append(root.id)
        }

        let depItems: [DependencyPlanItem] = root.dependencies.map { dep in
            let name = nodes[dep.id]?.name ?? dep.id
            let status: DependencyPlanItem.Status =
                installed[dep.id] != nil ? .alreadyInstalled : .willInstall
            return DependencyPlanItem(id: dep.id, name: name, version: dep.version, status: status)
        }

        // Expand transitive for disclosure: all non-primary in installOrder + already installed deps visited
        var disclosedIds = Set(depItems.map(\.id))
        var disclosed = depItems
        for id in order where id != root.id {
            guard !disclosedIds.contains(id), let node = nodes[id] else { continue }
            disclosedIds.insert(id)
            let status: DependencyPlanItem.Status =
                installed[id] != nil ? .alreadyInstalled : .willInstall
            disclosed.append(
                DependencyPlanItem(id: id, name: node.name, version: node.version, status: status)
            )
        }

        return DependencyPlan(
            primaryId: root.id,
            primaryName: root.name,
            dependencies: disclosed,
            installOrder: installOrder
        )
    }

    /// Job key for collision: segment after last `.`, or the whole id.
    public static func jobKey(for id: String) -> String {
        if let dot = id.lastIndex(of: ".") {
            return String(id[id.index(after: dot)...])
        }
        return id
    }

    public static func publisher(for id: String) -> String? {
        guard let dot = id.firstIndex(of: ".") else { return nil }
        return String(id[..<dot])
    }

    public static func checkCollision(installing: String, installedIds: [String]) throws {
        let job = jobKey(for: installing)
        let installingPub = publisher(for: installing)
        for occupant in installedIds where occupant != installing {
            guard jobKey(for: occupant) == job else { continue }
            let occupantPub = publisher(for: occupant)
            // Same full id already handled by version checks; different full ids sharing a job.
            if installingPub == "jugnu" {
                // First-party wins — allow proceed (replace path).
                continue
            }
            if occupantPub == "jugnu" || installingPub != nil {
                throw DependencyResolverError.collision(id: installing, occupant: occupant)
            }
        }
    }
}
