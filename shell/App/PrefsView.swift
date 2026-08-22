import JugnuCore
import SwiftUI

struct PrefsView: View {
    @ObservedObject var model: AppModel
    @State private var ids: [String] = []
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Addons").font(.title2.weight(.semibold))
            Text("Enable or uninstall packages under \(model.paths.addonsDir.path)")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(ids, id: \.self) { id in
                HStack {
                    VStack(alignment: .leading) {
                        Text(id).font(.headline)
                        Text(model.config.addons[id]?.enabled == true ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "Enabled",
                        isOn: Binding(
                            get: { model.config.addons[id]?.enabled == true },
                            set: { newValue in
                                do {
                                    try model.setEnabled(id: id, enabled: newValue)
                                    reload()
                                } catch {
                                    errorText = String(describing: error)
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    Button("Uninstall") {
                        do {
                            try model.uninstall(id: id)
                            reload()
                        } catch {
                            errorText = String(describing: error)
                        }
                    }
                }
            }

            Button("Install recommended from registry") {
                Task {
                    await model.installRecommendedFromRegistry()
                    reload()
                    if let status = model.statusMessage {
                        errorText = status
                    }
                }
            }

            Text("Registry: \(model.config.shell.registryURL)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let errorText {
                Text(errorText).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(16)
        .onAppear(perform: reload)
    }

    private func reload() {
        ids = model.installedAddonIDs()
        model.refreshIndex()
    }
}
