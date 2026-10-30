import Foundation

/// Where converted files land. The shell chooses the path; an addon never decides it.
/// Never overwrites: a taken name gets " 2", " 3", … before the extension.
public enum ConvertOutput {
    /// `directory/baseName.ext`, or the first free numbered sibling. Creates the file exclusively
    /// (O_EXCL) so two conversions cannot claim the same name; the addon then writes over the empty placeholder.
    public static func reserve(directory: URL, baseName: String, ext: String) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var attempt = 1
        while true {
            let name = attempt == 1 ? baseName : "\(baseName) \(attempt)"
            let url = directory.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
            let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY, 0o644)
            if fd >= 0 {
                close(fd)
                return url
            }
            guard errno == EEXIST else { throw CocoaError(.fileWriteUnknown) }
            attempt += 1
        }
    }

    /// File blocks: beside the original.
    public static func besideOriginal(_ input: URL, ext: String) throws -> URL {
        try reserve(
            directory: input.deletingLastPathComponent(),
            baseName: input.deletingPathExtension().lastPathComponent,
            ext: ext
        )
    }

    /// Text-block Download, and clipboard image data that has no original file.
    public static func inDownloads(_ downloads: URL, baseName: String, ext: String) throws -> URL {
        try reserve(directory: downloads, baseName: baseName, ext: ext)
    }
}
