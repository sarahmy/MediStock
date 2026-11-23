//
//  HistoryViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import Foundation
import Combine

// MARK: - Gestion de l'historique

@MainActor
final class HistoryViewModel: PagedViewModel<HistoryEntry> {

    // MARK: - Filtres

    @Published var filter: HistoryFilter

    // MARK: - Dépendances

    private let repository: InventoryRepository

    // MARK: - Initialisation

    init(
        medicineID: String? = nil,
        repository: InventoryRepository = FirestoreInventoryRepository()
    ) {
        self.filter = HistoryFilter(
            medicineID: medicineID
        )

        self.repository = repository

        super.init()
    }

    // MARK: - Rechargement

    func reload() async {

        // Conserver le filtre utilisé pour cette requête.
        let currentFilter = filter

        await load(reset: true) { cursor in

            try await self.repository.history(
                currentFilter,
                after: cursor
            )
        }
    }

    // MARK: - Pagination

    func loadMore() async {

        // Éviter que le filtre change
        // pendant la préparation de la requête.
        let currentFilter = filter

        await load(reset: false) { cursor in

            try await self.repository.history(
                currentFilter,
                after: cursor
            )
        }
    }
}
