import Foundation

/// Which Convert block may list an edge.
public enum ConvertMode: String, Codable, Equatable, Sendable, CaseIterable {
    case text
    case file
}

/// One directed conversion an addon can perform. The shell builds the Convert dropdowns from these.
public struct ConverterEdge: Codable, Equatable, Sendable {
    public var command: String
    public var from: String
    public var to: String
    public var modes: [ConvertMode]

    public init(command: String, from: String, to: String, modes: [ConvertMode]) {
        self.command = command
        self.from = from
        self.to = to
        self.modes = modes
    }

    enum CodingKeys: String, CodingKey {
        case command, from, to, modes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let commandID = try c.decode(String.self, forKey: .command)
        command = commandID
        from = try c.decode(String.self, forKey: .from)
        to = try c.decode(String.self, forKey: .to)
        modes = try c.decode([String].self, forKey: .modes).map { token in
            guard let mode = ConvertMode(rawValue: token) else {
                throw ManifestLoaderError.invalidConverter(commandID)
            }
            return mode
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(command, forKey: .command)
        try c.encode(from, forKey: .from)
        try c.encode(to, forKey: .to)
        try c.encode(modes.map(\.rawValue), forKey: .modes)
    }
}

/// A format an addon adds to the shell's core catalog. Ids already in the core catalog cannot be redefined.
public struct FormatDecl: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var extensions: [String]
    public var mime: String?

    public init(id: String, label: String, extensions: [String], mime: String? = nil) {
        self.id = id
        self.label = label
        self.extensions = extensions
        self.mime = mime
    }
}

/// Shell-owned core formats. Addons reference these ids in `converters:` and may add more via `formats:`.
public enum FormatCatalog {
    public static let core: [FormatDecl] = [
        FormatDecl(id: "json", label: "JSON", extensions: ["json"], mime: "application/json"),
        FormatDecl(id: "csv", label: "CSV", extensions: ["csv"], mime: "text/csv"),
        FormatDecl(id: "tsv", label: "TSV", extensions: ["tsv"], mime: "text/tab-separated-values"),
        FormatDecl(id: "yaml", label: "YAML", extensions: ["yaml", "yml"], mime: "application/yaml"),
        FormatDecl(id: "xml", label: "XML", extensions: ["xml"], mime: "application/xml"),
        FormatDecl(id: "markdown", label: "Markdown", extensions: ["md", "markdown"], mime: "text/markdown"),
        FormatDecl(id: "markdown-table", label: "Markdown table", extensions: ["md"], mime: "text/markdown"),
        FormatDecl(id: "html", label: "HTML", extensions: ["html", "htm"], mime: "text/html"),
        FormatDecl(id: "plain", label: "Plain text", extensions: ["txt"], mime: "text/plain"),
        FormatDecl(id: "pdf", label: "PDF", extensions: ["pdf"], mime: "application/pdf"),
        FormatDecl(id: "png", label: "PNG", extensions: ["png"], mime: "image/png"),
        FormatDecl(id: "jpeg", label: "JPEG", extensions: ["jpg", "jpeg"], mime: "image/jpeg"),
        FormatDecl(id: "heic", label: "HEIC", extensions: ["heic", "heif"], mime: "image/heic"),
        FormatDecl(id: "webp", label: "WebP", extensions: ["webp"], mime: "image/webp"),
        FormatDecl(id: "gif", label: "GIF", extensions: ["gif"], mime: "image/gif"),
        FormatDecl(id: "tiff", label: "TIFF", extensions: ["tif", "tiff"], mime: "image/tiff"),
        FormatDecl(id: "wav", label: "WAV", extensions: ["wav"], mime: "audio/wav"),
        FormatDecl(id: "aiff", label: "AIFF", extensions: ["aif", "aiff"], mime: "audio/aiff"),
        FormatDecl(id: "m4a", label: "M4A", extensions: ["m4a"], mime: "audio/mp4"),
        FormatDecl(id: "mp3", label: "MP3", extensions: ["mp3"], mime: "audio/mpeg"),
        FormatDecl(id: "caf", label: "CAF", extensions: ["caf"], mime: "audio/x-caf")
    ]

    public static let coreIDs: Set<String> = Set(core.map(\.id))

    /// Format ids are lowercase tokens: `json`, `markdown-table`.
    public static func isValidID(_ id: String) -> Bool {
        guard let first = id.unicodeScalars.first, first != "-" else { return false }
        return id.unicodeScalars.allSatisfy { ("a" ... "z").contains($0) || ("0" ... "9").contains($0) || $0 == "-" }
    }

    /// Extensions are stored lowercase with no leading dot.
    public static func isValidExtension(_ ext: String) -> Bool {
        !ext.isEmpty && ext.unicodeScalars.allSatisfy { ("a" ... "z").contains($0) || ("0" ... "9").contains($0) }
    }
}

/// First-party addons whose entrypoint is `kind: shell` (commands open shell-hosted UI; no addon process).
/// Keep in sync with scripts/validate-addon.sh FIRST_PARTY_SHELL_IDS.
public enum FirstPartyShellAddons {
    public static let ids: Set<String> = ["jugnu.convert"]
}

extension AddonManifest {
    /// Structural checks for `formats:`, `converters:` and a `shell` entrypoint.
    func validateConverters() throws {
        if entrypoint.isShell, !FirstPartyShellAddons.ids.contains(id) {
            throw ManifestLoaderError.shellEntrypointNotFirstParty(id)
        }

        var seenFormats = Set<String>()
        for format in formats {
            guard FormatCatalog.isValidID(format.id),
                  !FormatCatalog.coreIDs.contains(format.id),
                  seenFormats.insert(format.id).inserted,
                  !format.label.trimmingCharacters(in: .whitespaces).isEmpty,
                  !format.extensions.isEmpty,
                  format.extensions.allSatisfy(FormatCatalog.isValidExtension)
            else { throw ManifestLoaderError.invalidFormat(format.id) }
        }

        var seenEdges = Set<String>()
        for edge in converters {
            guard !entrypoint.isShell, !edge.modes.isEmpty, edge.from != edge.to else {
                throw ManifestLoaderError.invalidConverter(edge.command)
            }
            guard commands.contains(where: { $0.id == edge.command }) else {
                throw ManifestLoaderError.unknownConverterCommand(edge.command)
            }
            for token in [edge.from, edge.to] where !FormatCatalog.isValidID(token) {
                throw ManifestLoaderError.invalidFormat(token)
            }
            guard seenEdges.insert("\(edge.from)>\(edge.to)").inserted else {
                throw ManifestLoaderError.invalidConverter(edge.command)
            }
        }
    }
}
