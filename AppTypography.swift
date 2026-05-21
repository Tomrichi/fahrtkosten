import SwiftUI

// MARK: - App-weite Typografie (elegant, leicht)
//
// Alle Gewichte wurden bewusst reduziert für ein edleres Erscheinungsbild.
// .bold → .regular | .semibold → .light | .medium → .regular

extension View {
    func appTitle() -> some View {
        self.foregroundStyle(Color(.label).opacity(0.85))
    }
    func appSecondary() -> some View {
        self.foregroundStyle(Color(.secondaryLabel))
    }
    func appTertiary() -> some View {
        self.foregroundStyle(Color(.tertiaryLabel))
    }
}

struct AppHeadlineStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(.label).opacity(0.85))
    }
}

struct AppBodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color(.label).opacity(0.82))
    }
}

struct AppCaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color(.secondaryLabel))
    }
}

struct AppMonoStyle: ViewModifier {
    var size: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, design: .monospaced).weight(.light))
            .foregroundStyle(Color(.label).opacity(0.82))
    }
}

extension View {
    func appHeadline()   -> some View { modifier(AppHeadlineStyle()) }
    func appBody()       -> some View { modifier(AppBodyStyle()) }
    func appCaption()    -> some View { modifier(AppCaptionStyle()) }
    func appMono(_ size: CGFloat = 14) -> some View { modifier(AppMonoStyle(size: size)) }
}
