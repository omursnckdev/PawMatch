import SwiftUI

extension Color {
    /// Primary brand accent — warm orange (§9).
    static let pawOrange = Color(red: 1.0, green: 0.58, blue: 0.2) // #FF9433
}

extension Font {
    static func pawHeading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
