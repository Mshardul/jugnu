import Foundation

public struct ConvertTextPlan: Equatable, Sendable {
    public var detected: String
    public var source: String
    public var targets: [FormatDecl]
    public var target: String?
    public var route: ConvertRoute?

    public static func make(
        text: String,
        sourceOverride: String?,
        chosenTarget: String?,
        graph: ConvertGraph
    ) -> ConvertTextPlan {
        let detected = FormatDetector.detectText(text)
        let source = sourceOverride ?? detected
        let targets = graph.targets(from: source, mode: .text)
        let target = targets.contains(where: { $0.id == chosenTarget }) ? chosenTarget : targets.first?.id
        let route = target.flatMap { graph.route(from: source, to: $0, mode: .text) }
        return ConvertTextPlan(detected: detected, source: source, targets: targets, target: target, route: route)
    }
}
