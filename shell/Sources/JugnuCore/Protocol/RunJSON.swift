import Foundation

public enum RunJSONError: Error, Equatable {
    case invalidResponse
}

public enum RunJSON {
    public static func decodeResponse(stdout: Data) throws -> RunResponse {
        let trimmed = stdout.trimmingASCIIWhitespace
        guard !trimmed.isEmpty else { throw RunJSONError.invalidResponse }
        do {
            return try JSONDecoder().decode(RunResponse.self, from: trimmed)
        } catch {
            throw RunJSONError.invalidResponse
        }
    }

    public static func encodeRequest(_ request: RunRequest) throws -> Data {
        try JSONEncoder().encode(request)
    }

    public static func followUpRequest(command: String, args: [String: JSONValue]) -> RunRequest {
        RunRequest(api: 1, op: "run", command: command, args: args, context: [:])
    }
}

private extension Data {
    var trimmingASCIIWhitespace: Data {
        guard let s = String(data: self, encoding: .utf8) else { return self }
        return Data(s.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }
}
