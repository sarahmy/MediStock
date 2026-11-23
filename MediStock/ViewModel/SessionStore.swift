
//
//  SessionStore.swift
//  MediStock
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SessionStore: ObservableObject {

    enum AccessStatus: Equatable {
        case checking
        case allowed
        case denied
        case unavailable
    }

    @Published private(set) var user: FirebaseAuth.User?
    @Published private(set) var isChecking = true
    @Published private(set) var accessStatus: AccessStatus = .checking

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var accessListener: ListenerRegistration?

    // Empêche une ancienne réponse de modifier une nouvelle session.
    private var accessGeneration = 0

    // MARK: - Observer la connexion

    func startListening() {
        guard authHandle == nil else {
            return
        }

        Auth.auth().languageCode = "fr"

        authHandle = Auth.auth().addStateDidChangeListener {
            [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateSession()
            }
        }
    }

    private func updateSession() {
        let currentUser = Auth.auth().currentUser
        let accountChanged = user?.uid != currentUser?.uid

        user = currentUser
        isChecking = false

        guard currentUser != nil else {
            stopAccessListener()
            accessStatus = .checking
            return
        }

        if accountChanged || accessListener == nil {
            refreshAccess()
        }
    }

    // MARK: - Vérifier l'autorisation

    func refreshAccess() {
        stopAccessListener()
        accessStatus = .checking

        guard
            let currentUser = Auth.auth().currentUser,
            currentUser.uid == user?.uid
        else {
            accessStatus = .denied
            return
        }

        let uid = currentUser.uid
        let generation = accessGeneration

        accessListener = Firestore.firestore()
            .collection("authorizedUsers")
            .document(uid)
            .addSnapshotListener(
                includeMetadataChanges: true
            ) { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    guard SessionStoreRules.acceptsAccessCallback(
                        expectedGeneration: generation,
                        currentGeneration: self.accessGeneration,
                        expectedUID: uid,
                        sessionUID: self.user?.uid,
                        authenticatedUID: Auth.auth().currentUser?.uid
                    ) else {
                        return
                    }

                    self.accessStatus = SessionStoreRules.authorizationStatus(
                        hasError: error != nil,
                        hasSnapshot: snapshot != nil,
                        isFromCache: snapshot?.metadata.isFromCache ?? false,
                        hasPendingWrites: snapshot?.metadata.hasPendingWrites ?? false,
                        enabled: snapshot?.data()?["enabled"] as? Bool == true
                    )
                }
            }
    }

    private func stopAccessListener() {
        accessGeneration += 1
        accessListener?.remove()
        accessListener = nil
    }

    // MARK: - Connexion

    func signIn(
        email: String,
        password: String
    ) async throws {
        let email = try SessionStoreRules.signInEmail(
            email,
            password: password
        )

        do {
            _ = try await Auth.auth().signIn(
                withEmail: email,
                password: password
            )
        } catch {
            throw StockError.message(
                "Connexion impossible. Vérifie les identifiants "
                + "et la connexion Internet."
            )
        }

        updateSession()
    }

    // MARK: - Inscription

    func signUp(
        email: String,
        password: String,
        confirmation: String
    ) async throws {
        let email = try SessionStoreRules.signUpEmail(
            email,
            password: password,
            confirmation: confirmation
        )

        do {
            _ = try await Auth.auth().createUser(
                withEmail: email,
                password: password
            )
        } catch {
            throw StockError.message(
                "Inscription impossible. Vérifie les informations "
                + "ou utilise la connexion si tu as déjà un compte."
            )
        }

        // L'inscription ne crée aucune autorisation dans Firestore.
        updateSession()
    }

    // MARK: - Mot de passe oublié

    func resetPassword(email: String) async throws {
        let email = try SessionStoreRules.resetPasswordEmail(email)

        do {
            try await Auth.auth().sendPasswordReset(
                withEmail: email
            )
        } catch {
            throw StockError.message(
                "Demande indisponible. Réessaie plus tard."
            )
        }
    }

    // MARK: - Déconnexion

    func signOut() throws {
        try Auth.auth().signOut()
        updateSession()
    }

    // MARK: - Nettoyage des abonnements

    deinit {
        accessListener?.remove()

        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }
}
