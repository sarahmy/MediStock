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

    // MARK: - Session utilisateur

    @StateObject private var session: SessionStore

    // MARK: - Initialisation

    init() {

        // Configuration Firebase
        FirebaseApp.configure()

        // Configuration Firestore
        let database = Firestore.firestore()

        let settings = database.settings
        settings.cacheSettings = MemoryCacheSettings()
        database.settings = settings

        // Initialisation de la session
        _session = StateObject(
            wrappedValue: SessionStore()
        )
    }

    // MARK: - Interface principale

    var body: some Scene {

        WindowGroup {

            MediStockLaunchRouterView()
                .environmentObject(session)

        }
    }
}
