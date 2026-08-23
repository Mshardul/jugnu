import Foundation

public struct AddonWireItem: Encodable {
    public var id: String
    public var title: String
    public var subtitle: String?

    public init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public struct AddonWireField: Encodable {
    public var id: String
    public var label: String
    public var kind: String
    public var value: String?

    public init(id: String, label: String, kind: String, value: String? = nil) {
        self.id = id
        self.label = label
        self.kind = kind
        self.value = value
    }
}

public struct AddonWireUI: Encodable {
    public var pattern: String
    public var title: String?
    public var items: [AddonWireItem]?
    public var fields: [AddonWireField]?
    public var view: String?

    public init(
        pattern: String,
        title: String? = nil,
        items: [AddonWireItem]? = nil,
        fields: [AddonWireField]? = nil,
        view: String? = nil
    ) {
        self.pattern = pattern
        self.title = title
        self.items = items
        self.fields = fields
        self.view = view
    }
}

struct AddonWireBody: Encodable {
    var ok: Bool
    var message: String?
    var error: String?
    var ui: AddonWireUI?
}

public enum AddonWire {
    public static func encode(ok: Bool, message: String? = nil, error: String? = nil, ui: AddonWireUI? = nil) -> String {
        let body = AddonWireBody(ok: ok, message: message, error: error, ui: ui)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(body), let json = String(data: data, encoding: .utf8) else {
            return "{\"ok\":false,\"error\":\"Couldn’t build a reply.\"}"
        }
        return json
    }
}
