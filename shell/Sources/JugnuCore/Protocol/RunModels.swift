import Foundation

public enum UIPattern: String, Codable, Sendable, Equatable {
    case list
    case form
    case confirm
    case note
}

/// Minimal JSON value for `args` / `context` / form fields.
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([String: JSONValue])
    case array([JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .number(Double(i))
        } else if let d = try? c.decode(Double.self) {
            self = .number(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        }
    }
}

public struct UIListItem: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var actions: [String]?

    public init(id: String, title: String, subtitle: String? = nil, actions: [String]? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }
}

public struct UIFormField: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    public var kind: String
    public var value: JSONValue?

    public init(id: String, label: String, kind: String, value: JSONValue? = nil) {
        self.id = id
        self.label = label
        self.kind = kind
        self.value = value
    }
}

public struct UIDescriptor: Codable, Sendable, Equatable {
    public var pattern: UIPattern
    public var title: String?
    public var placeholder: String?
    public var message: String?
    public var items: [UIListItem]?
    public var fields: [UIFormField]?
    public var confirmLabel: String?
    public var cancelLabel: String?
    /// `.note` pattern: initial editable text content.
    public var content: String?
    public var view: ViewType?

    public init(
        pattern: UIPattern,
        title: String? = nil,
        placeholder: String? = nil,
        message: String? = nil,
        items: [UIListItem]? = nil,
        fields: [UIFormField]? = nil,
        confirmLabel: String? = nil,
        cancelLabel: String? = nil,
        content: String? = nil,
        view: ViewType? = nil
    ) {
        self.pattern = pattern
        self.title = title
        self.placeholder = placeholder
        self.message = message
        self.items = items
        self.fields = fields
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
        self.content = content
        self.view = view
    }
}

public struct RunRequest: Codable, Sendable, Equatable {
    public var api: Int
    public var op: String
    public var command: String
    public var args: [String: JSONValue]
    public var context: [String: JSONValue]?

    public init(
        api: Int = 1,
        op: String = "run",
        command: String,
        args: [String: JSONValue] = [:],
        context: [String: JSONValue]? = nil
    ) {
        self.api = api
        self.op = op
        self.command = command
        self.args = args
        self.context = context
    }
}

public struct RunResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var message: String?
    public var error: String?
    public var ui: UIDescriptor?

    public init(ok: Bool, message: String? = nil, error: String? = nil, ui: UIDescriptor? = nil) {
        self.ok = ok
        self.message = message
        self.error = error
        self.ui = ui
    }

    public func resolvingView(commandView: ViewType?, allowed: [ViewType]) throws -> RunResponse {
        guard var ui else { return self }
        ui.view = try ViewType.resolve(
            pattern: ui.pattern,
            requested: ui.view ?? commandView,
            allowed: allowed
        )
        var copy = self
        copy.ui = ui
        return copy
    }
}
