import Foundation

public struct ConvertFilePlan: Equatable, Sendable {
    public enum Problem: Equatable, Sendable {
        case noFiles
        case unrecognized(URL)
        case mixedFormats
        case noConversions(format: String)
    }

    public var files: [URL]
    public var source: String?
    public var targets: [FormatDecl]
    public var target: String?
    public var route: ConvertRoute?
    public var problem: Problem?

    public static func make(files: [URL], chosenTarget: String?, graph: ConvertGraph) -> ConvertFilePlan {
        guard !files.isEmpty else { return failing(files, .noFiles) }
        var detected: [String] = []
        for file in files {
            guard let format = FormatDetector.detectFile(at: file, formats: graph.formats) else {
                return failing(files, .unrecognized(file))
            }
            detected.append(format)
        }
        guard let source = detected.first, detected.allSatisfy({ $0 == source }) else {
            return failing(files, .mixedFormats)
        }
        let targets = graph.targets(from: source, mode: .file)
        guard !targets.isEmpty else {
            var plan = failing(files, .noConversions(format: source))
            plan.source = source
            return plan
        }
        let target = targets.contains(where: { $0.id == chosenTarget }) ? chosenTarget : targets.first?.id
        return ConvertFilePlan(
            files: files,
            source: source,
            targets: targets,
            target: target,
            route: target.flatMap { graph.route(from: source, to: $0, mode: .file) },
            problem: nil
        )
    }

    private static func failing(_ files: [URL], _ problem: Problem) -> ConvertFilePlan {
        ConvertFilePlan(files: files, source: nil, targets: [], target: nil, route: nil, problem: problem)
    }
}
