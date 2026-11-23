//
//  MedicineDetailViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import Combine

// MARK: - Détail d'un médicament

@MainActor
final class MedicineDetailViewModel: ObservableObject {

    @Published private(set) var medicine: Medicine?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    private let repository: InventoryRepository
    private let id: String

    private var generation = 0

    private var pending: (
        command: InventoryCommand,
        id: String
    )?

    init(
        id: String,
        repository: InventoryRepository = FirestoreInventoryRepository()
    ) {
        self.id = id
        self.repository = repository
    }

    // MARK: - Chargement

    func reload() async {
        generation += 1

        let ticket = generation
        isLoading = true

        defer {
            if ticket == generation {
                isLoading = false
            }
        }

        do {
            let value = try await repository.medicine(
                id: id
            )

            try Task.checkCancellation()

            guard ticket == generation else {
                return
            }

            medicine = value
            errorMessage = nil

        } catch is CancellationError {
            // La fermeture de l'écran peut
            // annuler son chargement.

        } catch {
            if ticket == generation {
                errorMessage = userMessage(error)
            }
        }
    }

    // MARK: - Modification du stock

    func changeStock(_ delta: Int) async -> Bool {
        await execute(
            .stock(
                id: id,
                delta: delta
            )
        )
    }

    // MARK: - Archivage

    func archive() async -> Bool {
        await execute(
            .archive(id: id)
        )
    }

    // MARK: - Exécution des commandes

    private func execute(
        _ command: InventoryCommand
    ) async -> Bool {

        guard !isSaving else {
            return false
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        if pending?.command != command {
            pending = (
                command,
                UUID().uuidString
            )
        }

        guard let operationID = pending?.id else {
            return false
        }

        do {
            try await repository.apply(
                command,
                operationID: operationID
            )

            pending = nil

            await reload()

            return true

        } catch {
            errorMessage = userMessage(error)
            return false
        }
    }
}
