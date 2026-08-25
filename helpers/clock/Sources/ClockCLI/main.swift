import ClockCore
import Darwin
import Foundation

private enum ClockCLIError: Error {
    case missingFile
    case missingTimer
    case missingID
    case missingSeconds
}

private func run(_ request: ClockRequest) throws -> ClockResponse {
    guard let file = request.file, !file.isEmpty else {
        throw ClockCLIError.missingFile
    }
    let store = ClockStore(fileURL: URL(fileURLWithPath: file))

    switch request.op {
    case .upsert:
        guard let timer = request.timer else {
            throw ClockCLIError.missingTimer
        }
        try store.upsert(timer)
        return ClockResponse(ok: true)
    case .cancel:
        guard let id = request.id else {
            throw ClockCLIError.missingID
        }
        try store.cancel(id: id)
        return ClockResponse(ok: true)
    case .pause:
        try store.pause(id: request.id, group: request.group)
        return ClockResponse(ok: true)
    case .resume:
        try store.resume(id: request.id, group: request.group)
        return ClockResponse(ok: true)
    case .list:
        return ClockResponse(ok: true, timers: try store.list())
    case .due:
        return ClockResponse(ok: true, timers: try store.due(now: request.now ?? Date()))
    case .markFired:
        guard let id = request.id else {
            throw ClockCLIError.missingID
        }
        try store.markFired(id: id, now: request.now ?? Date())
        return ClockResponse(ok: true)
    case .snooze:
        guard let id = request.id else {
            throw ClockCLIError.missingID
        }
        guard let seconds = request.seconds else {
            throw ClockCLIError.missingSeconds
        }
        try store.snooze(id: id, seconds: seconds, now: request.now ?? Date())
        return ClockResponse(ok: true)
    }
}

private func message(for error: Error) -> String {
    switch error {
    case ClockCLIError.missingFile:
        return "file is required"
    case ClockCLIError.missingTimer:
        return "timer is required"
    case ClockCLIError.missingID:
        return "id is required"
    case ClockCLIError.missingSeconds:
        return "seconds is required"
    case ClockStoreError.invalidSelector:
        return "id or group is required"
    case ClockStoreError.invalidTimer:
        return "timer is invalid"
    case ClockStoreError.invalidSnooze:
        return "snooze seconds must be positive"
    case ClockStoreError.timerNotFound(let id):
        return "timer not found: \(id)"
    default:
        return "clock request failed"
    }
}

private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}()

let response: ClockResponse
do {
    let request = try decoder.decode(
        ClockRequest.self,
        from: FileHandle.standardInput.readDataToEndOfFile()
    )
    response = try run(request)
} catch {
    response = ClockResponse(ok: false, error: message(for: error))
}

do {
    let data = try encoder.encode(response)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
} catch {
    exit(1)
}

exit(response.ok ? 0 : 1)
