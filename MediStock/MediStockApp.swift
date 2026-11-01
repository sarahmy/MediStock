//
//  MediStockApp.swift
//  MediStock
//
//  Created by Vincent Saluzzo on 28/05/2024.
//

import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
@MainActor
struct MediStockApp: App {

    @StateObject private var session: SessionStore

    private let authUITestScreen: String?

    init() {
        #if DEBUG && targetEnvironment(simulator)
        let screen = ProcessInfo.processInfo.environment[
            "MEDISTOCK_AUTH_UI_SCREEN"
        ]

        let supportedScreens: Set<String> = [
            "login", "signup", "stock", "aisles", "history",
            "account", "medicine-detail", "medicine-create",
            "medicine-edit", "main-tabs", "content", "theme-showcase"
        ]

        authUITestScreen = supportedScreens.contains(screen ?? "")
            ? screen
            : nil
        #else
        authUITestScreen = nil
        #endif

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let database = Firestore.firestore()
        let settings = database.settings

        settings.cacheSettings = MemoryCacheSettings()
        database.settings = settings

        _session = StateObject(
            wrappedValue: SessionStore()
        )
    }

    var body: some Scene {
        WindowGroup {
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
                        MedicineDetailView(medicineId: "ui-test-medicine")
                    }

                case "medicine-create":
                    MedicineFormView(initialAisle: "A1")

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

                case "theme-showcase":
                    CoverageThemeShowcase()

                default:
                    ContentView()
                }
            }
            .environmentObject(session)
        }
    }
}


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
                    ErrorBanner(message: "Erreur de démonstration")
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
                            MediStockTheme.supportingText(for: .light)
                        )

                    Text("Mode sombre")
                        .foregroundStyle(
                            MediStockTheme.supportingText(for: .dark)
                        )
                }
            }
            .mediStockScreen()
            .navigationTitle("Coverage Theme")
        }
        .accessibilityIdentifier("coverage.theme.screen")
    }
}
#endif
