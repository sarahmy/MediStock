//
//  AccountView.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import SwiftUI

@MainActor
struct AccountView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 12) {
                                accountIcon
                                accountInformation
                            }
                        } else {
                            HStack(alignment: .center, spacing: 16) {
                                accountIcon
                                accountInformation
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button {
                        do {
                            try session.signOut()
                        } catch {
                            errorMessage =
                                "Déconnexion impossible. Réessaie."
                        }
                    } label: {
                        Label(
                            "Se déconnecter",
                            systemImage:
                                "rectangle.portrait.and.arrow.right"
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage)
                    }
                }
            }
            .mediStockScreen()
            .navigationTitle("Mon compte")
        }
    }

    private var accountIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.largeTitle)
            .foregroundStyle(MediStockTheme.primary)
            .accessibilityHidden(true)
    }

    private var accountInformation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Adresse email")
                .font(.subheadline)
                .foregroundStyle(
                    MediStockTheme.supportingText(for: colorScheme)
                )

            Text(session.user?.email ?? "—")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adresse email du compte")
        .accessibilityValue(session.user?.email ?? "Non renseignée")
    }
}
