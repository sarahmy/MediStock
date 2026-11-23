//
//  MediStockHistoryViewModelTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 23/11/2026.
//



import Foundation
import XCTest
@testable import MediStock

/// Tests complémentaires de l'historique.
/// Aucun accès à Firebase réel.
final class MediStockHistoryViewModelExtraTests: XCTestCase {

    // MARK: - Initialisation

    @MainActor
    func testInitialHistoryFilterUsesMedicineID() async {
        let repository = HistoryPagingStub()

        let model = HistoryViewModel(
            medicineID: "m-42",
            repository: repository
        )

        XCTAssertEqual(model.filter.medicineID, "m-42")
        XCTAssertEqual(model.filter.sort, .newest)
        XCTAssertTrue(model.items.isEmpty)

        await model.reload()

        XCTAssertEqual(
            repository.requestedFilters.count,
            1
        )
        XCTAssertEqual(
            repository.requestedFilters[0].medicineID,
            "m-42"
        )
        XCTAssertFalse(model.hasMore)
        XCTAssertFalse(model.isLoading)
    }

    // MARK: - Filtres et tri

    @MainActor
    func testHistoryForwardsDateAndThenMedicineWithSortDirection() async {
        let repository = HistoryPagingStub()
        let model = HistoryViewModel(
            repository: repository
        )

        let day = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let byDate = HistoryFilter(
            day: day,
            sort: .oldest
        )

        model.filter = byDate
        await model.reload()

        let byMedicine = HistoryFilter(
            medicineID: "m-42",
            sort: .newest
        )

        model.filter = byMedicine
        await model.reload()

        XCTAssertEqual(
            repository.requestedFilters,
            [byDate, byMedicine]
        )
        XCTAssertNil(
            repository.requestedFilters[1].day
        )
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    // MARK: - Pagination

    @MainActor
    func testHistoryPagesAppendWithoutDuplicatingEvents() async {
        let repository = HistoryPagingStub()

        repository.pages = [
            Page(
                items: [
                    historyTestEntry(id: "e1")
                ],
                cursor: nil,
                hasMore: true
            ),
            Page(
                items: [
                    historyTestEntry(id: "e1"),
                    historyTestEntry(id: "e2")
                ],
                cursor: nil,
                hasMore: false
            )
        ]

        let model = HistoryViewModel(
            repository: repository
        )

        await model.reload()

        XCTAssertTrue(model.hasMore)
        XCTAssertEqual(
            model.items.map(\.id),
            ["e1"]
        )

        await model.loadMore()

        XCTAssertEqual(
            model.items.map(\.id),
            ["e1", "e2"]
        )
        XCTAssertFalse(model.hasMore)

        await model.loadMore()

        XCTAssertEqual(
            repository.requestedFilters.count,
            2,
            "Une page finale ne doit pas être rechargée"
        )
    }

    // MARK: - Changement de tri

    @MainActor
    func testReloadWithNewSortReplacesPreviousItems() async {
        let repository = HistoryPagingStub()

        repository.pages = [
            Page(
                items: [
                    historyTestEntry(id: "ancien")
                ],
                cursor: nil,
                hasMore: true
            ),
            Page(
                items: [
                    historyTestEntry(id: "nouveau")
                ],
                cursor: nil,
                hasMore: false
            )
        ]

        let model = HistoryViewModel(
            repository: repository
        )

        await model.reload()

        model.filter = HistoryFilter(
            sort: .oldest
        )

        await model.reload()

        XCTAssertEqual(
            model.items.map(\.id),
            ["nouveau"]
        )
        XCTAssertEqual(
            repository.requestedFilters.map(\.sort),
            [.newest, .oldest]
        )
        XCTAssertFalse(model.hasMore)
    }

    // MARK: - Erreur puis récupération

    @MainActor
    func testHistoryReadErrorCanBeRetriedSuccessfully() async {
        let repository = HistoryPagingStub()

        repository.nextError = StockError.message(
            "Lecture indisponible"
        )

        let model = HistoryViewModel(
            repository: repository
        )

        await model.reload()

        XCTAssertEqual(
            model.errorMessage,
            "Lecture indisponible"
        )
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.isLoading)

        repository.pages = [
            Page(
                items: [
                    historyTestEntry(id: "e1")
                ],
                cursor: nil,
                hasMore: false
            )
        ]

        await model.reload()

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(
            model.items.map(\.id),
            ["e1"]
        )
        XCTAssertFalse(model.isLoading)
    }

    // MARK: - Erreur pendant la pagination

    @MainActor
    func testLoadMoreErrorPreservesPreviousPageAndCanRetry() async {
        let repository = HistoryPagingStub()

        repository.pages = [
            Page(
                items: [
                    historyTestEntry(id: "e1")
                ],
                cursor: nil,
                hasMore: true
            )
        ]

        let model = HistoryViewModel(
            repository: repository
        )

        await model.reload()

        repository.nextError = StockError.message(
            "Réseau indisponible"
        )

        await model.loadMore()

        XCTAssertEqual(
            model.errorMessage,
            "Réseau indisponible"
        )
        XCTAssertEqual(
            model.items.map(\.id),
            ["e1"]
        )
        XCTAssertTrue(model.hasMore)
        XCTAssertFalse(model.isLoading)

        repository.pages = [
            Page(
                items: [
                    historyTestEntry(id: "e2")
                ],
                cursor: nil,
                hasMore: false
            )
        ]

        await model.loadMore()

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(
            model.items.map(\.id),
            ["e1", "e2"]
        )
        XCTAssertFalse(model.hasMore)
    }
}

// MARK: - Données de test

private func historyTestEntry(
    id: String
) -> HistoryEntry {

    let medicine = Medicine(
        id: "m-42",
        name: "Paracétamol",
        stock: 6,
        aisle: "A1"
    )

    return HistoryEntry(
        id: id,
        medicineId: medicine.id,
        userId: "test-user",
        userEmail: "test@example.com",
        action: "stock",
        before: nil,
        after: medicine,
        timestamp: Date(
            timeIntervalSince1970: 1_700_000_000
        )
    )
}

// MARK: - Repository simulé

private final class HistoryPagingStub: InventoryRepository {

    var pages: [Page<HistoryEntry>] = []
    var requestedFilters: [HistoryFilter] = []
    var nextError: Error?

    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {

        requestedFilters.append(filter)

        if let nextError {
            self.nextError = nil
            throw nextError
        }

        guard !pages.isEmpty else {
            return Page(
                items: [],
                cursor: nil,
                hasMore: false
            )
        }

        return pages.removeFirst()
    }

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        throw StockError.message(
            "Mauvaise surcharge de history"
        )
    }

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine> {
        Page(
            items: [],
            cursor: nil,
            hasMore: false
        )
    }

    func medicine(
        id: String
    ) async throws -> Medicine {
        throw StockError.missing
    }

    func aisles(
        after: PageCursor?
    ) async throws -> Page<Aisle> {
        Page(
            items: [],
            cursor: nil,
            hasMore: false
        )
    }

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws {}

    func createAisle(
        _ name: String
    ) async throws {}

    func deleteAisle(
        _ name: String
    ) async throws {}
}
