import Foundation

public enum ConvertOutput {
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

    public static func besideOriginal(_ input: URL, ext: String) throws -> URL {
        try reserve(
            directory: input.deletingLastPathComponent(),
            baseName: input.deletingPathExtension().lastPathComponent,
            ext: ext
        )
    }

    public static func inDownloads(_ downloads: URL, baseName: String, ext: String) throws -> URL {
        try reserve(directory: downloads, baseName: baseName, ext: ext)
    }
}
