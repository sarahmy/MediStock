//
//  MediStockRenameEdgeTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 23/11/2026.
//

import Foundation
import XCTest
@testable import MediStock

final class MediStockRenameEdgeTests: XCTestCase {

    func testEmptyAisleRenameCreatesTargetAndDeletesSource() async throws {
        let repository = RenameEdgeRepository()

        try await repository.renameAisle(from: "A1", to: " B1 ")

        XCTAssertEqual(repository.requestedFilters.count, 1)
        XCTAssertEqual(repository.requestedFilters.first?.aisle, "A1")
        XCTAssertEqual(repository.createdAisles, ["B1"])
        XCTAssertEqual(repository.deletedAisles, ["A1"])
        XCTAssertTrue(repository.commands.isEmpty)
    }

    func testInvalidAisleNameDoesNotTouchRepository() async {
        let repository = RenameEdgeRepository()

        do {
            try await repository.renameAisle(from: "A1", to: "A/B")
            XCTFail("La validation du nom devait échouer")
        } catch {
            XCTAssertTrue(repository.requestedFilters.isEmpty)
            XCTAssertTrue(repository.createdAisles.isEmpty)
            XCTAssertTrue(repository.deletedAisles.isEmpty)
            XCTAssertTrue(repository.commands.isEmpty)
        }
    }

    func testInitialReadFailureDoesNotCreateTarget() async {
        let repository = RenameEdgeRepository()
        repository.readError = StockError.message("Lecture impossible")

        do {
            try await repository.renameAisle(from: "A1", to: "B1")
            XCTFail("La lecture devait échouer")
        } catch {
            XCTAssertEqual(userMessage(error), "Lecture impossible")
            XCTAssertEqual(repository.requestedFilters.count, 1)
            XCTAssertTrue(repository.createdAisles.isEmpty)
            XCTAssertTrue(repository.deletedAisles.isEmpty)
            XCTAssertTrue(repository.commands.isEmpty)
        }
    }

    func testTargetCreationFailureDoesNotDeleteSource() async {
        let repository = RenameEdgeRepository()
        repository.createError = StockError.message(
            "Rayon cible déjà utilisé"
        )

        do {
            try await repository.renameAisle(from: "A1", to: "B1")
            XCTFail("La création du rayon cible devait échouer")
        } catch {
            XCTAssertEqual(
                userMessage(error),
                "Rayon cible déjà utilisé"
            )
            XCTAssertEqual(repository.createdAisles, ["B1"])
            XCTAssertTrue(repository.deletedAisles.isEmpty)
            XCTAssertTrue(repository.commands.isEmpty)
        }
    }

    func testMissingCursorLeavesOldAisleAndReportsInterruption() async {
        let repository = RenameEdgeRepository()
        repository.nextPage = Page(
            items: [renameMedicine()],
            cursor: nil,
            hasMore: true
        )

        do {
            try await repository.renameAisle(from: "A1", to: "B1")
            XCTFail("Un curseur manquant devait interrompre le renommage")
        } catch {
            XCTAssertTrue(
                userMessage(error).contains("Renommage interrompu")
            )
            XCTAssertEqual(repository.createdAisles, ["B1"])
            XCTAssertTrue(repository.deletedAisles.isEmpty)
            XCTAssertEqual(repository.commands.count, 1)
        }
    }

    func testDeleteFailureIsReportedWithoutMaskingPartialRename() async {
        let repository = RenameEdgeRepository()
        repository.deleteError = StockError.message(
            "Suppression refusée"
        )

        do {
            try await repository.renameAisle(from: "A1", to: "B1")
            XCTFail("La suppression devait échouer")
        } catch {
            let message = userMessage(error)
            XCTAssertTrue(message.contains("Renommage interrompu"))
            XCTAssertTrue(message.contains("Suppression refusée"))
            XCTAssertEqual(repository.createdAisles, ["B1"])
            XCTAssertEqual(repository.deletedAisles, ["A1"])
        }
    }
}

// MARK: - Données de test

private func renameMedicine() -> Medicine {
    Medicine(
        id: "m-test",
        name: "Test",
        stock: 17,
        aisle: "A1",
        archived: false,
        version: 1
    )
}

// MARK: - Repository simulé

private final class RenameEdgeRepository: InventoryRepository {

    var requestedFilters: [MedicineFilter] = []
    var createdAisles: [String] = []
    var deletedAisles: [String] = []
    var commands: [InventoryCommand] = []

    var readError: Error?
    var createError: Error?
    var deleteError: Error?

    var nextPage: Page<Medicine> = Page(
        items: [],
        cursor: nil,
        hasMore: false
    )

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine> {
        requestedFilters.append(filter)
        if let readError { throw readError }
        return nextPage
    }

    func medicine(id: String) async throws -> Medicine {
        throw StockError.missing
    }

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        Page(items: [], cursor: nil, hasMore: false)
    }

    func aisles(after: PageCursor?) async throws -> Page<Aisle> {
        Page(items: [], cursor: nil, hasMore: false)
    }

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws {
        commands.append(command)
    }

    func createAisle(_ name: String) async throws {
        createdAisles.append(name)
        if let createError { throw createError }
    }

    func deleteAisle(_ name: String) async throws {
        deletedAisles.append(name)
        if let deleteError { throw deleteError }
    }
}
