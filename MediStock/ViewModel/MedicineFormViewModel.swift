//
//  MedicineFormViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import Combine

// MARK: - Formulaire médicament

@MainActor
final class MedicineFormViewModel: ObservableObject {

    @Published var name: String
    @Published var aisle: String
    @Published var stockText: String

    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    let original: Medicine?

    private let creationID = UUID().uuidString
    private let repository: InventoryRepository

    private var pending: (
        command: InventoryCommand,
        id: String
    )?

    init(
        medicine: Medicine? = nil,
        initialAisle: String = "",
        repository: InventoryRepository = FirestoreInventoryRepository()
    ) {
        original = medicine
        self.repository = repository

        name = medicine?.name ?? ""
        aisle = medicine?.aisle ?? initialAisle
        stockText = String(medicine?.stock ?? 0)
    }

    // MARK: - Enregistrement

    func save() async -> Bool {

        guard !isSaving else {
            return false
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            guard let stock = original?.stock ?? Int(stockText) else {
                throw StockError.invalidStock
            }

            let clean = try MedicineValidation.validate(
                name: name,
                stock: stock,
                aisle: aisle
            )

            let command: InventoryCommand

            if let original {
                command = .edit(
                    original,
                    name: clean.name,
                    aisle: clean.aisle
                )
            } else {
                command = .create(
                    Medicine(
                        id: creationID,
                        name: clean.name,
                        stock: stock,
                        aisle: clean.aisle
                    )
                )
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

            try await repository.apply(
                command,
                operationID: operationID
            )

            pending = nil
            return true

        } catch {
            errorMessage = userMessage(error)
            return false
        }
    }
}
