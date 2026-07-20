import SwiftUI

// AppStyle: sowas wie CSS
// https://www.swift.org/documentation/docc/customizing-the-appearance-of-your-documentation-pages
enum AppStyle {
    static let orange = Color(hex: 0xff7700)
    static let teal = Color(hex: 0x009393)
    static let lime = Color(hex: 0xafca0b)
    static let magenta = Color(hex: 0xe50b7c)
    static let blue = Color(hex: 0x12719f)
    static let yellow = Color(hex: 0xffd200)

    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let elevatedSurface = Color(.tertiarySystemGroupedBackground)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)

    static let brandGradient = LinearGradient(
        colors: [orange, magenta, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subjectPalette = [orange, teal, lime, magenta, blue]

    static func subjectColor(for value: String?) -> Color {
        guard let value else {
            return teal
        }

        let total = value.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }

        return subjectPalette[abs(total) % subjectPalette.count]
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    static let interLargeTitle = Font.custom("Inter", size: 34, relativeTo: .largeTitle).weight(.bold)
    static let interTitle = Font.custom("Inter", size: 28, relativeTo: .title).weight(.bold)
    static let interTitle2 = Font.custom("Inter", size: 22, relativeTo: .title2).weight(.semibold)
    static let interTitle3 = Font.custom("Inter", size: 20, relativeTo: .title3).weight(.semibold)
    static let interHeadline = Font.custom("Inter", size: 17, relativeTo: .headline).weight(.semibold)
    static let interBody = Font.custom("Inter", size: 17, relativeTo: .body)
    static let interSubheadline = Font.custom("Inter", size: 15, relativeTo: .subheadline)
    static let interCaption = Font.custom("Inter", size: 12, relativeTo: .caption)
    static let interCaption2 = Font.custom("Inter", size: 11, relativeTo: .caption2)
}
