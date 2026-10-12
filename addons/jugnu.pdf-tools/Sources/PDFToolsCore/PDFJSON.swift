import Foundation

enum PDFJSON {
    static func ok(_ message: String) -> String {
        encode(["message": message, "ok": true])
    }

    static func fail(_ error: String) -> String {
        encode(["error": error, "ok": false])
    }

    static func form(title: String, fields: [[String: String]]) -> String {
        encode([
            "ok": true,
            "ui": [
                "fields": fields,
                "pattern": "form",
                "title": title,
                "view": "fields",
            ] as [String: Any],
        ])
    }

    static func list(title: String, items: [[String: String]]) -> String {
        encode([
            "ok": true,
            "ui": [
                "items": items,
                "pattern": "list",
                "title": title,
                "view": "rows",
            ] as [String: Any],
        ])
    }

    static func note(title: String, content: String) -> String {
        encode([
            "ok": true,
            "ui": [
                "content": content,
                "pattern": "note",
                "title": title,
            ] as [String: Any],
        ])
    }

    static func textField(id: String, label: String, value: String) -> [String: String] {
        ["id": id, "kind": "text", "label": label, "value": value]
    }

    private static func encode(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"Couldn’t build a reply.\",\"ok\":false}"
        }
        return json
    }
}
