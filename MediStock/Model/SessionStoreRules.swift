//
//  SessionStoreRules.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//

import Foundation

@MainActor
enum SessionStoreRules {

    // MARK: - Validation de la connexion

    static func signInEmail(
        _ email: String,
        password: String
    ) throws -> String {
        let cleanedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanedEmail.isEmpty, !password.isEmpty else {
            throw StockError.message(
                "Renseigne l'email et le mot de passe."
            )
        }

        return cleanedEmail
    }

    // MARK: - Validation de l'inscription

    static func signUpEmail(
        _ email: String,
        password: String,
        confirmation: String
    ) throws -> String {
        let cleanedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard cleanedEmail.contains("@"),
              !cleanedEmail.contains(" ") else {
            throw StockError.message(
                "Vérifie le format de l'adresse email."
            )
        }

        guard password.count >= 6 else {
            throw StockError.message(
                "Le mot de passe doit contenir au moins 6 caractères."
            )
        }

        guard password == confirmation else {
            throw StockError.message(
                "Les mots de passe ne correspondent pas."
            )
        }

        return cleanedEmail
    }

    // MARK: - Validation du mot de passe oublié

    static func resetPasswordEmail(_ email: String) throws -> String {
        let cleanedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard cleanedEmail.contains("@") else {
            throw StockError.message(
                "Renseigne ton adresse email."
            )
        }

        return cleanedEmail
    }

    // MARK: - Protection contre les anciennes sessions

    static func acceptsAccessCallback(
        expectedGeneration: Int,
        currentGeneration: Int,
        expectedUID: String,
        sessionUID: String?,
        authenticatedUID: String?
    ) -> Bool {
        expectedGeneration == currentGeneration
            && sessionUID == expectedUID
            && authenticatedUID == expectedUID
    }

    // MARK: - Autorisation confirmée par Firestore

    static func authorizationStatus(
        hasError: Bool,
        hasSnapshot: Bool,
        isFromCache: Bool,
        hasPendingWrites: Bool,
        enabled: Bool
    ) -> SessionStore.AccessStatus {
        // Une absence de réponse ou une erreur n'accorde aucun accès.
        guard !hasError, hasSnapshot else {
            return .unavailable
        }

        // Une donnée issue du cache ou en attente d'écriture ne suffit pas.
        guard !isFromCache, !hasPendingWrites else {
            return .checking
        }

        // Seul un document confirmé par le serveur avec enabled == true
        // autorise l'accès. Un document absent ou incomplet est refusé.
        return enabled ? .allowed : .denied
    }
}
