//
//  MediStockTheme.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import SwiftUI

// MARK: - Couleurs communes

enum MediStockTheme {
    static let primary = Color("Brand")

    static let logoStart = Color(
        red: 0.31,
        green: 0.26,
        blue: 0.55
    )

    static let logoEnd = Color(
        red: 0.40,
        green: 0.34,
        blue: 0.65
    )

    static func backgroundColors(
        for scheme: ColorScheme
    ) -> [Color] {
        if scheme == .dark {
            return [
                Color(red: 0.17, green: 0.14, blue: 0.25),
                Color(red: 0.12, green: 0.10, blue: 0.18),
                Color(red: 0.08, green: 0.07, blue: 0.12)
            ]
        }

        return [
            Color(red: 0.78, green: 0.75, blue: 0.93),
            Color(red: 0.89, green: 0.87, blue: 0.97),
            Color(red: 0.96, green: 0.95, blue: 0.98)
        ]
    }

    static func supportingText(
        for scheme: ColorScheme
    ) -> Color {
        scheme == .dark
            ? Color(red: 0.84, green: 0.82, blue: 0.91)
            : Color(red: 0.24, green: 0.22, blue: 0.31)
    }

    static func navigationColor(
        for scheme: ColorScheme
    ) -> Color {
        scheme == .dark
            ? Color(red: 0.18, green: 0.15, blue: 0.27)
            : Color(red: 0.81, green: 0.78, blue: 0.94)
    }

    static func tabColor(
        for scheme: ColorScheme
    ) -> Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.10, blue: 0.18)
            : Color(red: 0.94, green: 0.92, blue: 0.98)
    }
}

// MARK: - Fond partagé

struct MediStockBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: MediStockTheme.backgroundColors(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Style commun aux écrans

private struct MediStockScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background {
                MediStockBackground()
                    .ignoresSafeArea()
            }
            .toolbarBackground(
                MediStockTheme.navigationColor(for: scheme),
                for: .navigationBar
            )
            .toolbarBackground(
                .visible,
                for: .navigationBar
            )
            .toolbarBackground(
                MediStockTheme.tabColor(for: scheme),
                for: .tabBar
            )
            .toolbarBackground(
                .visible,
                for: .tabBar
            )
            .tint(MediStockTheme.primary)
            .environment(\.defaultMinListRowHeight, 54)
    }
}

extension View {
    func mediStockScreen() -> some View {
        modifier(MediStockScreenModifier())
    }
}

// MARK: - Logo textuel

@MainActor
struct MediStockLogo: View {
    @ScaledMetric(relativeTo: .largeTitle)
    private var large = 42.0

    @ScaledMetric(relativeTo: .title)
    private var small = 29.0

    var body: some View {
        (
            Text("M")
                .font(
                    .system(
                        size: large,
                        weight: .semibold,
                        design: .rounded
                    )
                )
            +
            Text("ediStoc")
                .font(
                    .system(
                        size: small,
                        weight: .medium,
                        design: .rounded
                    )
                )
            +
            Text("K")
                .font(
                    .system(
                        size: large,
                        weight: .semibold,
                        design: .rounded
                    )
                )
        )
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background {
            LinearGradient(
                colors: [
                    MediStockTheme.logoStart,
                    MediStockTheme.logoEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    Color.white.opacity(0.18),
                    lineWidth: 1
                )
        }
        .accessibilityLabel("MediStock")
    }
}

// MARK: - Message d'erreur

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(
            message,
            systemImage: "exclamationmark.triangle"
        )
        .foregroundStyle(.red)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mot de passe avec bouton œil

struct PasswordInput: View {
    let title: String
    @Binding var text: String

    var newPassword = false
    var identifier = "password"

    @State private var visible = false
    @FocusState private var isFocused: Bool
    @Environment(\.scenePhase) private var phase

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Group {
                    if visible {
                        TextField(title, text: $text)
                            .focused($isFocused)
                    } else {
                        SecureField(title, text: $text)
                            .focused($isFocused)
                    }
                }
                .textContentType(
                    newPassword ? .newPassword : .password
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier)
                .submitLabel(.done)
                .onSubmit {
                    isFocused = false
                }

                Button {
                    visible.toggle()
                } label: {
                    Image(
                        systemName: visible
                        ? "eye.slash"
                        : "eye"
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    visible
                    ? "Masquer le mot de passe"
                    : "Afficher le mot de passe"
                )
                .accessibilityIdentifier(
                    identifier + ".eye"
                )
                .accessibilityValue(
                    visible ? "visible" : "masqué"
                )
            }
        }
        .onChange(of: phase) { _, value in
            if value == .background {
                visible = false
                isFocused = false
            }
        }
    }
}
