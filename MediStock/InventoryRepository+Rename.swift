//
//  InventoryRepository+Rename.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation

// MARK: - Renommage des rayons

extension InventoryRepository {

    func renameAisle(
        from oldName: String,
        to input: String
    ) async throws {

        let newName = try MedicineValidation.aisle(input)

        guard newName != oldName else {
            return
        }

        let filter = MedicineFilter(
            aisle: oldName
        )

        var page = try await medicines(
            filter,
            after: nil
        )

        // Refuse un nom déjà utilisé.
        try await createAisle(newName)

        do {
            while true {
                try Task.checkCancellation()

                for medicine in page.items {
                    try Task.checkCancellation()

                    try await apply(
                        .edit(
                            medicine,
                            name: medicine.name,
                            aisle: newName
                        ),
                        operationID: UUID().uuidString
                    )
                }

                guard page.hasMore else {
                    break
                }

                guard let cursor = page.cursor else {
                    throw StockError.corrupted
                }

                page = try await medicines(
                    filter,
                    after: cursor
                )
            }

            try await deleteAisle(oldName)

        } catch {
            throw StockError.message(
                "Renommage interrompu. Certaines références peuvent "
                + "déjà être dans « \(newName) ». "
                + "Vérifie les deux rayons avant de poursuivre. "
                + userMessage(error)
            )
        }
    }
}
