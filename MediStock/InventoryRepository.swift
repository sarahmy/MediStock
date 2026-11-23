//
//  InventoryRepository.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import Foundation

struct Page<Item> {
    let items: [Item]
    let cursor: PageCursor?
    let hasMore: Bool
}

protocol InventoryRepository {

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine>

    func medicine(id: String) async throws -> Medicine

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry>

    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry>

    func aisles(
        after: PageCursor?
    ) async throws -> Page<Aisle>

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws

    func createAisle(_ name: String) async throws

    func deleteAisle(_ name: String) async throws
}

extension InventoryRepository {

    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {

        guard !filter.usesAdvancedFilters else {
            throw StockError.message(
                "Les filtres avancés ne sont pas disponibles avec ce dépôt."
            )
        }

        return try await history(
            medicineID: filter.medicineID,
            after: after
        )
    }
}
