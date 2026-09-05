import CryptoKit
import Foundation

public struct AddonInstaller: Sendable {
    public let paths: JugnuPaths
    public let store: ConfigStore
    private let downloads: any InstallDownloading

    public init(
        paths: JugnuPaths,
        store: ConfigStore? = nil,
        downloads: any InstallDownloading = AllowlistedDownloadSession()
    ) {
        self.paths = paths
        self.store = store ?? ConfigStore(paths: paths)
        self.downloads = downloads
    }

    /// Install a catalog entry. When the package (or registry row) declares `dependencies`,
    /// resolves a plan, optionally discloses via `confirmDependencies`, then commits as one transaction.
    public func install(
        entry: RegistryEntry,
        enable: Bool,
        catalog: [RegistryEntry] = [],
        installedVersions: [String: String]? = nil,
        confirmDependencies: ((DependencyPlan) async -> Bool)? = nil
    ) async throws {
        guard let remote = URL(string: entry.url), !entry.url.isEmpty else {
            throw AddonInstallerError.missingURL
        }
        let tempURL = try await downloads.download(remote)
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(entry.id)-\(UUID().uuidString).zip")
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.moveItem(at: tempURL, to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try await installZipWithDependencies(
            zipURL: zipURL,
            expectedSHA256: entry.sha256,
            enable: enable,
            expectedId: entry.id,
            catalog: catalog.isEmpty ? [entry] : catalog,
            installedVersions: installedVersions ?? readInstalledAddonVersions(),
            confirmDependencies: confirmDependencies
        )
    }

    public func installFromLocalZip(
        url: URL,
        expectedSHA256: String?,
        enable: Bool,
        addonId: String? = nil
    ) throws {
        try requireSHA256(expectedSHA256, of: url)

        let extractRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractRoot) }

        try ZipExtractor.extract(zipURL: url, to: extractRoot)
        let packageRoot = try ZipExtractor.findPackageRoot(in: extractRoot, manifestName: "addon.yaml")
        var manifest = try ManifestLoader.load(from: packageRoot)
        let id = addonId ?? manifest.id
        if id != manifest.id {
            if id == NamespaceMigrator.namespacedId(forJob: manifest.id) {
                try rewriteManifestId(at: packageRoot, from: manifest.id, to: id)
                manifest = try ManifestLoader.load(from: packageRoot)
            } else {
                throw AddonInstallerError.idMismatch(expected: id, actual: manifest.id)
            }
        }

        try commitAddonPackage(from: packageRoot, id: id, enable: enable)
    }

    /// Install an already-unpacked addon directory (dev / first-run local path).
    public func installFromDirectory(url: URL, enable: Bool) throws {
        let manifest = try ManifestLoader.load(from: url)
        try commitAddonPackage(from: url, id: manifest.id, enable: enable)
    }

    public func installHelperFromLocalZip(
        url: URL,
        expectedSHA256: String?,
        id: String,
        version: String
    ) throws {
        try requireSHA256(expectedSHA256, of: url)

        let extractRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-helper-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractRoot) }

        try ZipExtractor.extract(zipURL: url, to: extractRoot)
        let packageRoot = try ZipExtractor.findPackageRoot(in: extractRoot, manifestName: "helper.yaml")
        let manifest = try ManifestLoader.loadHelper(from: packageRoot)
        guard manifest.id == id, manifest.version == version else {
            throw AddonInstallerError.helperManifestMismatch(
                expectedId: id,
                expectedVersion: version,
                actualId: manifest.id,
                actualVersion: manifest.version
            )
        }

        try commitHelperPackage(from: packageRoot, id: id, version: version)
    }

    public func ensureHelpers(for manifest: AddonManifest) async throws {
        for ref in manifest.helpers {
            let yaml = paths.helperRoot(id: ref.id, version: ref.version).appendingPathComponent("helper.yaml")
            if FileManager.default.fileExists(atPath: yaml.path) {
                continue
            }
            let (entry, zipURL) = try await fetchHelperZip(ref: ref)
            defer { try? FileManager.default.removeItem(at: zipURL) }
            try installHelperFromLocalZip(
                url: zipURL,
                expectedSHA256: entry.sha256,
                id: ref.id,
                version: ref.version
            )
        }
    }

    /// Wipe orphaned `.staging` / `.trash` trees (call on launch).
    public func recoverInstallOrphans() {
        AtomicCommit.recoverOrphans(stagingParent: paths.addonsStagingDir, trashParent: paths.addonsTrashDir)
        AtomicCommit.recoverOrphans(stagingParent: paths.helpersStagingDir, trashParent: paths.helpersTrashDir)
    }

    public func readInstalledAddonVersions() -> [String: String] {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(
            at: paths.addonsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }
        var out: [String: String] = [:]
        for dir in kids {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let name = dir.lastPathComponent
            if name.hasPrefix(".") { continue }
            if let manifest = try? ManifestLoader.load(from: dir) {
                out[manifest.id] = manifest.version
            }
        }
        return out
    }

    // MARK: - Dependency-aware install

    private func installZipWithDependencies(
        zipURL: URL,
        expectedSHA256: String?,
        enable: Bool,
        expectedId: String?,
        catalog: [RegistryEntry],
        installedVersions: [String: String],
        confirmDependencies: ((DependencyPlan) async -> Bool)?
    ) async throws {
        try requireSHA256(expectedSHA256, of: zipURL)

        let extractRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractRoot) }

        try ZipExtractor.extract(zipURL: zipURL, to: extractRoot)
        let packageRoot = try ZipExtractor.findPackageRoot(in: extractRoot, manifestName: "addon.yaml")
        var manifest = try ManifestLoader.load(from: packageRoot)
        if let expectedId, expectedId != manifest.id {
            if expectedId == NamespaceMigrator.namespacedId(forJob: manifest.id) {
                try rewriteManifestId(at: packageRoot, from: manifest.id, to: expectedId)
                manifest = try ManifestLoader.load(from: packageRoot)
            } else {
                throw AddonInstallerError.idMismatch(expected: expectedId, actual: manifest.id)
            }
        }

        let root = DeclaredAddon(
            id: manifest.id,
            name: manifest.name,
            version: manifest.version,
            dependencies: manifest.dependencies
        )
        var declared: [String: DeclaredAddon] = Dictionary(
            uniqueKeysWithValues: catalog.map { ($0.id, DeclaredAddon(entry: $0)) }
        )
        declared[root.id] = root

        // Prefer manifest deps; if registry listed deps for root, merge unknown ids only via catalog.
        let plan: DependencyPlan
        do {
            plan = try DependencyResolver.plan(
                root: root,
                catalog: declared,
                installed: installedVersions
            )
        } catch let error as DependencyResolverError {
            throw AddonInstallerError.dependency(error)
        }

        if plan.needsDisclosure {
            let ok = await confirmDependencies?(plan) ?? true
            if !ok {
                throw AddonInstallerError.dependencyDisclosureDeclined
            }
        }

        if plan.installOrder.count == 1, plan.dependencies.isEmpty {
            try commitAddonPackage(from: packageRoot, id: manifest.id, enable: enable)
            try await ensureHelpers(for: manifest)
            return
        }

        var tx = InstallTransaction(paths: paths, store: store)
        var stagedAddons: [String: URL] = [:]
        var stagedHelpers: [(ref: HelperRef, staging: URL)] = []
        var manifestsById: [String: AddonManifest] = [manifest.id: manifest]

        do {
            for id in plan.installOrder {
                let pkgRoot: URL
                if id == manifest.id {
                    pkgRoot = packageRoot
                } else {
                    guard let entry = catalog.first(where: { $0.id == id }) else {
                        throw AddonInstallerError.dependency(.unknown(id: id))
                    }
                    pkgRoot = try await downloadAndExtractAddon(entry: entry)
                }
                let m: AddonManifest
                do {
                    var loaded = try ManifestLoader.load(from: pkgRoot)
                    if id != loaded.id,
                       id == NamespaceMigrator.namespacedId(forJob: loaded.id)
                    {
                        try rewriteManifestId(at: pkgRoot, from: loaded.id, to: id)
                        loaded = try ManifestLoader.load(from: pkgRoot)
                    } else if id != loaded.id {
                        throw AddonInstallerError.idMismatch(expected: id, actual: loaded.id)
                    }
                    m = loaded
                }
                manifestsById[id] = m
                stagedAddons[id] = try stageAddonPackage(from: pkgRoot, id: id)
                if id != manifest.id {
                    try? FileManager.default.removeItem(at: pkgRoot)
                }
            }

            var helperRefs: [HelperRef] = []
            var seenHelper = Set<String>()
            for id in plan.installOrder {
                guard let m = manifestsById[id] else { continue }
                for ref in m.helpers {
                    let key = "\(ref.id)@\(ref.version)"
                    if seenHelper.insert(key).inserted {
                        helperRefs.append(ref)
                    }
                }
            }

            for ref in helperRefs {
                let yaml = paths.helperRoot(id: ref.id, version: ref.version).appendingPathComponent("helper.yaml")
                if FileManager.default.fileExists(atPath: yaml.path) { continue }
                let (entry, zip) = try await fetchHelperZip(ref: ref)
                defer { try? FileManager.default.removeItem(at: zip) }
                let staging = try stageHelperFromZip(
                    url: zip,
                    expectedSHA256: entry.sha256,
                    id: ref.id,
                    version: ref.version
                )
                stagedHelpers.append((ref, staging))
            }

            for item in stagedHelpers {
                try tx.commitHelper(staging: item.staging, id: item.ref.id, version: item.ref.version)
            }
            try tx.commitAddons(
                staged: stagedAddons,
                order: plan.installOrder,
                primaryId: manifest.id,
                enablePrimary: enable
            )
        } catch {
            tx.rollback()
            for staging in stagedAddons.values {
                try? FileManager.default.removeItem(at: staging)
            }
            for item in stagedHelpers {
                try? FileManager.default.removeItem(at: item.staging)
            }
            throw error
        }
    }

    // MARK: - Stage / commit

    private func stageAddonPackage(from packageRoot: URL, id: String) throws -> URL {
        let manifest = try ManifestLoader.load(from: packageRoot)
        try PackageGates.checkMinShellVersion(
            required: manifest.minShellVersion,
            running: ShellVersion.current
        )
        let entryURL = packageRoot.appendingPathComponent(manifest.entrypoint.path)
        try PackageGates.checkEntrypoint(kind: manifest.entrypoint.kind, fileURL: entryURL)

        let fm = FileManager.default
        try fm.createDirectory(at: paths.addonsStagingDir, withIntermediateDirectories: true)
        let staging = paths.addonsStagingDir.appendingPathComponent("\(id)-\(UUID().uuidString)")
        if fm.fileExists(atPath: staging.path) {
            try fm.removeItem(at: staging)
        }
        try fm.copyItem(at: packageRoot, to: staging)
        return staging
    }

    private func commitAddonPackage(from packageRoot: URL, id: String, enable: Bool) throws {
        let staging = try stageAddonPackage(from: packageRoot, id: id)
        let live = paths.addonsDir.appendingPathComponent(id)
        try AtomicCommit.promote(staging: staging, live: live, trashParent: paths.addonsTrashDir)

        var config = try store.loadOrCreateDefaults()
        config.addons[id] = AddonConfig(enabled: enable)
        try store.save(config)
    }

    private func stageHelperFromZip(
        url: URL,
        expectedSHA256: String?,
        id: String,
        version: String
    ) throws -> URL {
        try requireSHA256(expectedSHA256, of: url)

        let extractRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-helper-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractRoot) }

        try ZipExtractor.extract(zipURL: url, to: extractRoot)
        let packageRoot = try ZipExtractor.findPackageRoot(in: extractRoot, manifestName: "helper.yaml")
        let manifest = try ManifestLoader.loadHelper(from: packageRoot)
        guard manifest.id == id, manifest.version == version else {
            throw AddonInstallerError.helperManifestMismatch(
                expectedId: id,
                expectedVersion: version,
                actualId: manifest.id,
                actualVersion: manifest.version
            )
        }
        return try stageHelperPackage(from: packageRoot, id: id, version: version)
    }

    private func stageHelperPackage(from packageRoot: URL, id: String, version: String) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.helpersStagingDir, withIntermediateDirectories: true)
        let staging = paths.helpersStagingDir
            .appendingPathComponent("\(id)-\(version)-\(UUID().uuidString)")
        if fm.fileExists(atPath: staging.path) {
            try fm.removeItem(at: staging)
        }
        try fm.copyItem(at: packageRoot, to: staging)
        return staging
    }

    private func commitHelperPackage(from packageRoot: URL, id: String, version: String) throws {
        let staging = try stageHelperPackage(from: packageRoot, id: id, version: version)
        let live = paths.helperRoot(id: id, version: version)
        try AtomicCommit.promote(staging: staging, live: live, trashParent: paths.helpersTrashDir)
    }

    private func downloadAndExtractAddon(entry: RegistryEntry) async throws -> URL {
        guard let remote = URL(string: entry.url), !entry.url.isEmpty else {
            throw AddonInstallerError.missingURL
        }
        let tempURL = try await downloads.download(remote)
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(entry.id)-\(UUID().uuidString).zip")
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.moveItem(at: tempURL, to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try requireSHA256(entry.sha256, of: zipURL)
        let extractRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)
        try ZipExtractor.extract(zipURL: zipURL, to: extractRoot)
        let packageRoot = try ZipExtractor.findPackageRoot(in: extractRoot, manifestName: "addon.yaml")
        // Copy out of extract root so defer cleanup of zip is fine; keep extractRoot until caller done.
        // Caller owns lifetime via staging copy — return packageRoot under extractRoot that must survive.
        // Move extract root aside without defer delete: re-copy to a durable temp.
        let durable = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-pkg-\(entry.id)-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: packageRoot, to: durable)
        try? FileManager.default.removeItem(at: extractRoot)
        return durable
    }

    private func fetchHelperZip(ref: HelperRef) async throws -> (HelperRegistryEntry, URL) {
        let config = try store.loadOrCreateDefaults()
        let catalog = ShellConfig.helpersCatalogURL(from: config.shell.registryURL)
        guard let catalogURL = URL(string: catalog) else {
            throw AddonInstallerError.helperUnreachable
        }
        let entries: [HelperRegistryEntry]
        do {
            entries = try await RegistryClient().fetchHelpers(from: catalogURL)
        } catch {
            throw AddonInstallerError.helperUnreachable
        }
        guard let entry = entries.first(where: { $0.id == ref.id && $0.version == ref.version }) else {
            throw AddonInstallerError.helperNotInCatalog(id: ref.id, version: ref.version)
        }
        guard let remote = URL(string: entry.url), !entry.url.isEmpty else {
            throw AddonInstallerError.missingURL
        }
        let zipURL: URL
        do {
            let tempURL = try await downloads.download(remote)
            zipURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(entry.id)-\(entry.version)-\(UUID().uuidString).zip")
            try? FileManager.default.removeItem(at: zipURL)
            try FileManager.default.moveItem(at: tempURL, to: zipURL)
        } catch let error as AddonInstallerError {
            if case .hostNotAllowed = error { throw error }
            throw AddonInstallerError.helperUnreachable
        } catch {
            throw AddonInstallerError.helperUnreachable
        }
        return (entry, zipURL)
    }

    private func requireSHA256(_ expectedSHA256: String?, of url: URL) throws {
        guard let expected = expectedSHA256?.lowercased(), !expected.isEmpty else {
            throw AddonInstallerError.sha256Required
        }
        let data = try Data(contentsOf: url)
        let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw AddonInstallerError.sha256Mismatch(expected: expected, actual: actual)
        }
    }

    /// Transitional: rewrite bare `id: job` → `jugnu.job` when installing an older published zip
    /// against a namespaced registry row.
    private func rewriteManifestId(at packageRoot: URL, from oldId: String, to newId: String) throws {
        let file = packageRoot.appendingPathComponent("addon.yaml")
        var text = try String(contentsOf: file, encoding: .utf8)
        guard let range = text.range(of: "id: \(oldId)") else {
            throw AddonInstallerError.idMismatch(expected: newId, actual: oldId)
        }
        text.replaceSubrange(range, with: "id: \(newId)")
        try text.write(to: file, atomically: true, encoding: .utf8)
    }
}

public enum AddonInstallerError: Error, Equatable {
    case missingURL
    case sha256Required
    case sha256Mismatch(expected: String, actual: String)
    case idMismatch(expected: String, actual: String)
    case addonYAMLMissing
    case unsafeArchive
    case archiveTooLarge
    case hostNotAllowed
    case downloadFailed
    case helperYAMLMissing
    case helperManifestMismatch(
        expectedId: String, expectedVersion: String, actualId: String, actualVersion: String
    )
    case helperUnreachable
    case helperNotInCatalog(id: String, version: String)
    case shellTooOld(required: String, running: String)
    case invalidMinShellVersion(String)
    case nonUniversalBinary
    case dependency(DependencyResolverError)
    case dependencyDisclosureDeclined

    @available(*, deprecated, renamed: "unsafeArchive")
    public static var unzipFailed: AddonInstallerError { .unsafeArchive }
}
