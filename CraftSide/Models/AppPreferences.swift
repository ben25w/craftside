import SwiftUI

enum SidebarSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum InsertPlacement: String, CaseIterable, Identifiable {
    case start
    case end
    case before
    case after

    var id: String { rawValue }

    var label: String {
        switch self {
        case .start: "Top"
        case .end: "Bottom"
        case .before: "Before Selected"
        case .after: "After Selected"
        }
    }
}
