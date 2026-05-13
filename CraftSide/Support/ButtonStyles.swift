import SwiftUI

struct PlainIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(configuration.isPressed ? CraftPalette.purple : .primary)
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? CraftPalette.purpleSoft : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

extension ButtonStyle where Self == PlainIconButtonStyle {
    static var plainIcon: PlainIconButtonStyle { PlainIconButtonStyle() }
}
