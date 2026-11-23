//
//  AislesViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import Combine

// MARK: - Gestion des rayons

@MainActor
final class AislesViewModel: PagedViewModel<Aisle> {

    @Published private(set) var isSaving = false

    private let repository: InventoryRepository

    init(
        repository: InventoryRepository =
            FirestoreInventoryRepository()
    ) {
        self.repository = repository
        super.init()
    }

    // MARK: - Chargement

    func reload() async {
        guard !isSaving else {
            return
        }

        await refreshList()
    }

    func loadMore() async {
        guard !isSaving else {
            return
        }

        await load(reset: false) {
            try await self.repository.aisles(
                after: $0
            )
        }
    }

    private func refreshList() async {
        await load(reset: true) {
            try await self.repository.aisles(
                after: $0
            )
        }
    }

    // MARK: - Création et suppression

    func save(
        name: String,
        deleting: Bool = false
    ) async {
        await perform {
            if deleting {
                try await self.repository.deleteAisle(
                    name
                )
            } else {
                try await self.repository.createAisle(
                    name
                )
            }
        }
    }

    // MARK: - Renommage

    func rename(
        from oldName: String,
        to newName: String
    ) async {
        await perform {
            try await self.repository.renameAisle(
                from: oldName,
                to: newName
            )
        }
    }

    // MARK: - Opérations communes

    private func perform(
        _ operation: () async throws -> Void
    ) async {
        guard !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            try await operation()
            await refreshList()

        } catch {
            let message = userMessage(error)

            // Un renommage interrompu peut
            // avoir déplacé des références.
            await refreshList()

            errorMessage = message
        }
    }
}
