import Foundation

public enum AppApplyHelper {
    public static func write(dir: URL, pid: Int32, sourceApp: URL, destApp: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let planURL = dir.appendingPathComponent("plan.json")
        try JSONSerialization.data(
            withJSONObject: [
                "pid": Int(pid),
                "source": sourceApp.path,
                "dest": destApp.path
            ],
            options: [.sortedKeys]
        ).write(to: planURL)
        let script = dir.appendingPathComponent("apply.sh")
        let body = """
        #!/bin/sh
        set -e
        PID=\(pid)
        SOURCE=\(shellSingleQuoted(sourceApp.path))
        DEST=\(shellSingleQuoted(destApp.path))
        i=0
        while kill -0 "$PID" 2>/dev/null; do
          i=$((i + 1))
          if [ "$i" -gt 60 ]; then
            exit 1
          fi
          sleep 0.25
        done
        ditto "$SOURCE" "$DEST"
        xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
        open "$DEST"
        rm -rf "$(dirname "$SOURCE")"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
