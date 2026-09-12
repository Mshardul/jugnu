import Foundation
import Yams

public enum AddonConfigValueType: String, Codable, Sendable, Equatable {
    case string
    case int
    case bool
    case `enum`
}

public struct AddonConfigField: Codable, Equatable, Sendable {
    public var key: String
    public var type: AddonConfigValueType
    public var values: [String]?
    public var `default`: JSONValue

    public init(key: String, type: AddonConfigValueType, values: [String]? = nil, default: JSONValue) {
        self.key = key
        self.type = type
        self.values = values
        self.default = `default`
    }
}

public enum AddonConfigError: Error, Equatable, Sendable {
    case invalidSchema(String)
    case syntaxError
    case unknownKey(String)
    case invalidValue(key: String, reason: String)
}

public enum AddonConfigResolver {
    public static func validateSchema(_ fields: [AddonConfigField]) throws {
        var seen = Set<String>()
        for field in fields {
            guard field.key.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil else {
                throw AddonConfigError.invalidSchema("bad key \(field.key)")
            }
            guard seen.insert(field.key).inserted else {
                throw AddonConfigError.invalidSchema("duplicate key \(field.key)")
            }
            if field.type == .enum {
                guard let values = field.values, !values.isEmpty else {
                    throw AddonConfigError.invalidSchema("enum \(field.key) needs values")
                }
            } else if field.values != nil {
                throw AddonConfigError.invalidSchema("\(field.key) values only for enum")
            }
            try assertMatches(field.default, field: field, label: "default")
        }
    }

    /// missing file falls back to schema defaults; empty schema yields [:]
    public static func resolve(schema: [AddonConfigField], fileURL: URL) throws -> [String: JSONValue] {
        try validateSchema(schema)
        guard !schema.isEmpty else { return [:] }

        var resolved: [String: JSONValue] = [:]
        for field in schema {
            resolved[field.key] = field.default
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return resolved }

        let text: String
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw AddonConfigError.syntaxError
        }

        let parsed: [String: Any]
        do {
            parsed = try YamsLoad.loadMap(text)
        } catch {
            throw AddonConfigError.syntaxError
        }

        let byKey = Dictionary(uniqueKeysWithValues: schema.map { ($0.key, $0) })
        for (key, raw) in parsed {
            guard let field = byKey[key] else {
                throw AddonConfigError.unknownKey(key)
            }
            let value = try jsonValue(from: raw, field: field)
            resolved[key] = value
        }
        return resolved
    }

    public static func templateYAML(schema: [AddonConfigField]) -> String {
        fileYAML(schema: schema, values: Dictionary(uniqueKeysWithValues: schema.map { ($0.key, $0.default) }))
    }

    public static func fileYAML(schema: [AddonConfigField], values: [String: JSONValue]) -> String {
        var lines = ["# Generated defaults — edit values, keep keys."]
        for field in schema {
            let comment = switch field.type {
            case .enum:
                " # enum: \((field.values ?? []).joined(separator: "|"))"
            case .int:
                " # int"
            case .bool:
                " # bool"
            case .string:
                " # string"
            }
            let value = values[field.key] ?? field.default
            lines.append("\(field.key): \(yamlScalar(value))\(comment)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func writeFile(schema: [AddonConfigField], values: [String: JSONValue], to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try fileYAML(schema: schema, values: values).write(to: url, atomically: true, encoding: .utf8)
    }

    public static func reason(for error: AddonConfigError) -> String {
        switch error {
        case let .invalidSchema(reason):
            reason
        case .syntaxError:
            "YAML syntax error"
        case let .unknownKey(key):
            "unknown key \(key)"
        case let .invalidValue(key, reason):
            "\(key): \(reason)"
        }
    }

    private static func assertMatches(_ value: JSONValue, field: AddonConfigField, label: String) throws {
        switch field.type {
        case .string:
            guard case .string = value else {
                throw AddonConfigError.invalidSchema("\(label) for \(field.key) must be string")
            }
        case .int:
            guard case let .number(n) = value, n.rounded() == n else {
                throw AddonConfigError.invalidSchema("\(label) for \(field.key) must be int")
            }
        case .bool:
            guard case .bool = value else {
                throw AddonConfigError.invalidSchema("\(label) for \(field.key) must be bool")
            }
        case .enum:
            guard case let .string(s) = value, (field.values ?? []).contains(s) else {
                throw AddonConfigError.invalidSchema("\(label) for \(field.key) must be enum value")
            }
        }
    }

    private static func jsonValue(from raw: Any, field: AddonConfigField) throws -> JSONValue {
        switch field.type {
        case .string:
            guard let s = raw as? String else {
                throw AddonConfigError.invalidValue(key: field.key, reason: "expected string")
            }
            return .string(s)
        case .int:
            if let i = raw as? Int {
                return .number(Double(i))
            }
            if let i64 = raw as? Int64 {
                return .number(Double(i64))
            }
            throw AddonConfigError.invalidValue(key: field.key, reason: "expected int")
        case .bool:
            guard let b = raw as? Bool else {
                throw AddonConfigError.invalidValue(key: field.key, reason: "expected bool")
            }
            return .bool(b)
        case .enum:
            guard let s = raw as? String, (field.values ?? []).contains(s) else {
                throw AddonConfigError.invalidValue(key: field.key, reason: "expected enum value")
            }
            return .string(s)
        }
    }

    private static func yamlScalar(_ value: JSONValue) -> String {
        switch value {
        case let .string(s):
            if s.contains(":") || s.contains("#") || s.contains("\"") {
                return "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return s
        case let .number(n):
            if n.rounded() == n {
                return String(Int(n))
            }
            return String(n)
        case let .bool(b):
            return b ? "true" : "false"
        case .null:
            return "null"
        case .object, .array:
            return "null"
        }
    }
}

enum YamsLoad {
    static func loadMap(_ text: String) throws -> [String: Any] {
        guard let root = try Yams.load(yaml: text) else {
            throw AddonConfigError.syntaxError
        }
        guard let map = root as? [String: Any] else {
            throw AddonConfigError.syntaxError
        }
        return map
    }
}
