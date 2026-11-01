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

        authUITestScreen = ["login", "signup"].contains(screen ?? "")
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
                if authUITestScreen == "login" {
                    LoginView()

                } else if authUITestScreen == "signup" {
                    NavigationStack {
                        AuthenticationForm(signup: true)
                    }

                } else {
                    ContentView()
                }
            }
            .environmentObject(session)
        }
    }
}
