//
//  HistoryViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HistoryViewModel: PagedViewModel<HistoryEntry> {
    @Published var filter: HistoryFilter

    private let repository: InventoryRepository

    init(
        medicineID: String? = nil,
        repository: InventoryRepository =
            FirestoreInventoryRepository()
    ) {
        self.filter = HistoryFilter(
            medicineID: medicineID
        )
        self.repository = repository
        super.init()
    }

    func reload() async {
        await load(reset: true) {
            try await self.repository.history(
                self.filter,
                after: $0
            )
        }
    }

    func loadMore() async {
        await load(reset: false) {
            try await self.repository.history(
                self.filter,
                after: $0
            )
        }
    }
}

// MARK: - Recherche des auteurs de l'historique

protocol HistoryAuthorsRepository: Sendable {
    func allAuthorEmails() async throws -> [String]
}

actor FirestoreHistoryAuthorsRepository:
    HistoryAuthorsRepository {

    private let sessionUID =
        Auth.auth().currentUser?.uid

    func allAuthorEmails() async throws -> [String] {
        guard let sessionUID,
              Auth.auth().currentUser?.uid == sessionUID
        else {
            throw StockError.disconnected
        }

        var emails: [String] = []
        var lastEmail: String?

        // Parcourt les emails distincts de tout l'historique.
        // Chaque requête est limitée à un document.
        while true {
            try Task.checkCancellation()

            var query: Query = Firestore.firestore()
                .collection("history")
                .order(by: "userEmail")
                .limit(to: 1)

            if let lastEmail {
                // Saute tous les événements portant
                // l'email déjà trouvé.
                query = query.start(
                    after: [lastEmail]
                )
            }

            let result = try await query.getDocuments(
                source: .server
            )

            try Task.checkCancellation()

            guard Auth.auth().currentUser?.uid ==
                    sessionUID else {
                throw StockError.disconnected
            }

            guard let document =
                    result.documents.first else {
                return emails
            }

            guard let email =
                    document.data()["userEmail"] as? String,
                  !email.isEmpty
            else {
                throw StockError.corrupted
            }

            // Protection contre une pagination incorrecte.
            guard email != lastEmail else {
                throw StockError.corrupted
            }

            emails.append(email)
            lastEmail = email
        }
    }
}

// MARK: - État du menu des utilisateurs

@MainActor
final class HistoryAuthorsViewModel: ObservableObject {
    @Published private(set) var emails: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private let repository: any HistoryAuthorsRepository

    init(
        repository: any HistoryAuthorsRepository =
            FirestoreHistoryAuthorsRepository()
    ) {
        self.repository = repository
    }

    func reload() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let values =
                try await repository.allAuthorEmails()

            try Task.checkCancellation()

            emails = values
            hasLoaded = true

        } catch is CancellationError {
            // L'annulation de la navigation
            // n'est pas une erreur utilisateur.

        } catch {
            errorMessage = userMessage(error)
        }
    }
}
