import SwiftUI

/// Native palette picker bound to the accent preference.
struct AccentPalettePicker: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Accent.allCases) { accent in
                let selected = prefs.accentColor == accent.rawValue
                Button {
                    guard !selected else { return }
                    prefs.accentColor = accent.rawValue
                    Haptics.light()
                } label: {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .overlay(Circle().strokeBorder(.primary.opacity(selected ? 0.3 : 0), lineWidth: 2))
                        .frame(width: 44, height: 44) // HIG minimum hit target
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accent.label)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
                .animation(.snappy(duration: 0.2), value: selected)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.s("accentColor"))
    }
}

/// Native segmented control bound to the theme preference.
struct ThemeModePicker: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        Picker(L.s("appearanceTitle"), selection: $prefs.themeMode) {
            Label(L.s("themeDark"), systemImage: "moon.fill").tag("dark")
            Label(L.s("themeAuto"), systemImage: "circle.lefthalf.filled").tag("system")
            Label(L.s("themeLight"), systemImage: "sun.max.fill").tag("light")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: prefs.themeMode) { Haptics.light() }
    }
}
