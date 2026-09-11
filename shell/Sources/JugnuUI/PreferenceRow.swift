import JugnuCore
import SwiftUI

public struct PreferenceRow<Control: View>: View {
    let title: String
    let description: String?
    let titleColor: Color
    let descriptionColor: Color
    @ViewBuilder var control: () -> Control

    public init(
        title: String,
        description: String? = nil,
        titleColor: Color = .primary,
        descriptionColor: Color = .secondary,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.description = description
        self.titleColor = titleColor
        self.descriptionColor = descriptionColor
        self.control = control
    }

    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(titleColor)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(descriptionColor)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 8)
    }
}
