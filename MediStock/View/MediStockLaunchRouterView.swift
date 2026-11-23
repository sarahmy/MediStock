//
//  MediStockLaunchRouterView.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import SwiftUI

@MainActor
struct MediStockLaunchRouterView: View {

    // MARK: - Configuration des tests UI

    private let authUITestScreen: String?

    // MARK: - Initialisation

    init() {

        #if DEBUG && targetEnvironment(simulator)

        let screen = ProcessInfo.processInfo.environment[
            "MEDISTOCK_AUTH_UI_SCREEN"
        ]

        let supportedScreens: Set<String> = [
            "login",
            "signup",
            "stock",
            "aisles",
            "history",
            "account",
            "medicine-detail",
            "medicine-create",
            "medicine-edit",
            "main-tabs",
            "content",
            "theme-showcase"
        ]

        authUITestScreen = supportedScreens.contains(
            screen ?? ""
        ) ? screen : nil

        #else

        authUITestScreen = nil

        #endif
    }

    // MARK: - Interface

    var body: some View {

        Group {

            switch authUITestScreen {

            case "login":

                LoginView()

            case "signup":

                NavigationStack {
                    AuthenticationForm(signup: true)
                }

            case "stock":

                AllMedicinesView()

            case "aisles":

                AisleListView()

            case "history":

                AuditLogView()

            case "account":

                AccountView()

            case "medicine-detail":

                NavigationStack {
                    MedicineDetailView(
                        medicineId: "ui-test-medicine"
                    )
                }

            case "medicine-create":

                MedicineFormView(
                    initialAisle: "A1"
                )

            case "medicine-edit":

                MedicineFormView(
                    medicine: Medicine(
                        id: "ui-test-medicine",
                        name: "Paracétamol",
                        stock: 12,
                        aisle: "A1",
                        version: 1
                    )
                )

            case "main-tabs":

                MainTabView()

            case "content":

                ContentView()

            #if DEBUG && targetEnvironment(simulator)

            case "theme-showcase":

                CoverageThemeShowcase()

            #endif

            default:

                ContentView()
            }
        }
    }
}

// MARK: - Écran de couverture du thème

#if DEBUG && targetEnvironment(simulator)

@MainActor
private struct CoverageThemeShowcase: View {

    @State private var password = "secret"

    var body: some View {

        NavigationStack {

            List {

                Section {

                    MediStockLogo()

                }

                Section {

                    ErrorBanner(
                        message: "Erreur de démonstration"
                    )

                }

                Section {

                    PasswordInput(
                        title: "Mot de passe de démonstration",
                        text: $password,
                        newPassword: true,
                        identifier: "coverage.password"
                    )

                }

                Section {

                    Text("Couverture thème")
                        .foregroundStyle(
                            MediStockTheme.supportingText(
                                for: .light
                            )
                        )

                    Text("Mode sombre")
                        .foregroundStyle(
                            MediStockTheme.supportingText(
                                for: .dark
                            )
                        )

                }
            }
            .mediStockScreen()
            .navigationTitle("Coverage Theme")
        }
        .accessibilityIdentifier(
            "coverage.theme.screen"
        )
    }
}

#endif
