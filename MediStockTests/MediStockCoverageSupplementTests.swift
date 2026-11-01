//
//  MediStockCoverageSupplementTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 31/10/2026.
//

import XCTest
import SwiftUI
@testable import MediStock

final class MediStockCoverageSupplementTests: XCTestCase {

    // MARK: - Modèles / enums

    func testMedicineAndAisleEqualityAndIdentifiers() {
        let medicine = Medicine(
            id: "m1",
            name: "Paracétamol",
            stock: 12,
            aisle: "A1",
            archived: false,
            version: 3
        )
        XCTAssertEqual(medicine.id, "m1")
        XCTAssertEqual(medicine, medicine)

        let aisle = Aisle(id: "A1", count: 4)
        XCTAssertEqual(aisle.id, "A1")
        XCTAssertEqual(aisle, Aisle(id: "A1", count: 4))

        XCTAssertEqual(MedicineSort.name.id, "Nom")
        XCTAssertEqual(MedicineSort.stock.id, "Stock")
        XCTAssertEqual(MedicineSort.stockDescending.id, "Stock décroissant")
    }

    func testEveryInventoryCommandReturnsItsMedicineID() {
        let medicine = Medicine(id: "m42", name: "Test", stock: 1, aisle: "A")
        XCTAssertEqual(InventoryCommand.create(medicine).medicineID, "m42")
        XCTAssertEqual(InventoryCommand.edit(medicine, name: "N", aisle: "B").medicineID, "m42")
        XCTAssertEqual(InventoryCommand.stock(id: "m42", delta: 1).medicineID, "m42")
        XCTAssertEqual(InventoryCommand.archive(id: "m42").medicineID, "m42")
    }

    // MARK: - Validation

    func testAisleValidationAcceptsTrimmedUnicodeName() throws {
        XCTAssertEqual(try MedicineValidation.aisle("  Médicaments bébé  "), "Médicaments bébé")
    }

    func testAisleValidationRejectsAllReservedForms() {
        let invalid = ["", "   ", ".", "..", "A/B", "__secret__", "A\nB"]
        for value in invalid {
            XCTAssertThrowsError(try MedicineValidation.aisle(value), "Devait refuser: \(value)")
        }
    }

    func testNameAndStockBoundaries() throws {
        let eighty = String(repeating: "a", count: 80)
        let clean = try MedicineValidation.validate(name: "  \(eighty)  ", stock: 1_000_000, aisle: "A")
        XCTAssertEqual(clean.name, eighty)
        XCTAssertEqual(clean.aisle, "A")

        XCTAssertThrowsError(
            try MedicineValidation.validate(name: String(repeating: "a", count: 81), stock: 0, aisle: "A")
        )
        XCTAssertThrowsError(
            try MedicineValidation.validate(name: "A", stock: -1, aisle: "A")
        )
        XCTAssertThrowsError(
            try MedicineValidation.validate(name: "A", stock: 1_000_001, aisle: "A")
        )
    }

    func testAdjustedStockDetectsIntegerOverflow() {
        XCTAssertThrowsError(try MedicineValidation.adjustedStock(current: Int.max, delta: 1))
        XCTAssertThrowsError(try MedicineValidation.adjustedStock(current: Int.min, delta: -1))
    }

    // MARK: - Messages d'erreur

    func testEveryStockErrorHasUserFacingText() {
        let errors: [StockError] = [
            .invalidName, .invalidAisle, .invalidStock, .missing,
            .conflict, .disconnected, .corrupted, .message("Personnalisé")
        ]
        for error in errors {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty)
            XCTAssertFalse(userMessage(error).isEmpty)
        }
        XCTAssertEqual(userMessage(StockError.message("Personnalisé")), "Personnalisé")
    }

    func testFirestoreErrorMappingsAndFallback() {
        XCTAssertTrue(userMessage(NSError(domain: "FIRFirestoreErrorDomain", code: 7)).contains("accès"))
        XCTAssertTrue(userMessage(NSError(domain: "FIRFirestoreErrorDomain", code: 9)).contains("résultats"))
        XCTAssertTrue(userMessage(NSError(domain: "FIRFirestoreErrorDomain", code: 14)).contains("Connexion"))
        XCTAssertTrue(userMessage(NSError(domain: "Autre", code: 123)).contains("Impossible"))
    }

    // MARK: - Historique

    func testHistoryEntryTitlesCoverUnknownAction() {
        let after = medicine(stock: 5)
        XCTAssertEqual(entry(action: "create", before: nil, after: after).title, "Création")
        XCTAssertEqual(entry(action: "edit", before: medicine(stock: 4), after: after).title, "Modification")
        XCTAssertEqual(entry(action: "stock", before: medicine(stock: 4), after: after).title, "Changement de stock")
        XCTAssertEqual(entry(action: "archive", before: medicine(stock: 4), after: after).title, "Retrait du stock")
        XCTAssertEqual(entry(action: "other", before: medicine(stock: 4), after: after).title, "Opération")
    }

    func testHistoryEntryDetailsCoverAllBranches() {
        let before = Medicine(id: "m1", name: "Ancien", stock: 4, aisle: "A1")
        let after = Medicine(id: "m1", name: "Nouveau", stock: 5, aisle: "B2")

        XCTAssertTrue(entry(action: "create", before: nil, after: after).details.contains("Nouveau"))
        XCTAssertTrue(entry(action: "stock", before: before, after: after).details.contains("4 → 5"))
        XCTAssertTrue(entry(action: "archive", before: before, after: after).details.contains("retiré"))
        XCTAssertTrue(entry(action: "edit", before: before, after: after).details.contains("Ancien → Nouveau"))
        XCTAssertTrue(entry(action: "unknown", before: before, after: after).details.contains("A1 → B2"))
    }

    func testHistoryFilterAdvancedFlagsAndSortIDs() {
        XCTAssertEqual(HistorySort.newest.id, "Plus récentes d’abord")
        XCTAssertEqual(HistorySort.oldest.id, "Plus anciennes d’abord")
        XCTAssertTrue(HistorySort.newest.descending)
        XCTAssertFalse(HistorySort.oldest.descending)

        var filter = HistoryFilter()
        XCTAssertFalse(filter.usesAdvancedFilters)
        filter.userEmail = " x@y.com "
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter = HistoryFilter(medicineName: "Doliprane")
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter = HistoryFilter(aisle: "A1")
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter = HistoryFilter(day: Date())
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter = HistoryFilter(sort: .oldest)
        XCTAssertTrue(filter.usesAdvancedFilters)
    }

    // MARK: - Extension InventoryRepository

    func testDefaultHistoryExtensionForwardsSimpleFilter() async throws {
        let repo = CoverageRepository()
        _ = try await repo.history(HistoryFilter(medicineID: "m9"), after: nil)
        XCTAssertEqual(repo.historyMedicineIDs, ["m9"])
    }

    func testDefaultHistoryExtensionRejectsAdvancedFilter() async {
        let repo = CoverageRepository()
        do {
            _ = try await repo.history(HistoryFilter(userEmail: "a@b.com"), after: nil)
            XCTFail("Une recherche avancée devait être refusée")
        } catch {
            XCTAssertTrue(userMessage(error).contains("filtres avancés"))
        }
        XCTAssertTrue(repo.historyMedicineIDs.isEmpty)
    }

    func testRenameSameAisleDoesNotTouchRepository() async throws {
        let repo = CoverageRepository()
        try await repo.renameAisle(from: "A1", to: " A1 ")
        XCTAssertTrue(repo.createdAisles.isEmpty)
        XCTAssertTrue(repo.deletedAisles.isEmpty)
        XCTAssertTrue(repo.appliedCommands.isEmpty)
    }

    func testRenameAisleMovesAllMedicinesThenDeletesOldAisle() async throws {
        let repo = CoverageRepository()
        repo.medicinePages = [
            Page(items: [medicine(id: "1"), medicine(id: "2")], cursor: nil, hasMore: false)
        ]

        try await repo.renameAisle(from: "A1", to: " B2 ")

        XCTAssertEqual(repo.createdAisles, ["B2"])
        XCTAssertEqual(repo.deletedAisles, ["A1"])
        XCTAssertEqual(repo.appliedCommands.count, 2)
        for command in repo.appliedCommands {
            guard case let .edit(original, name, aisle) = command else {
                return XCTFail("Commande edit attendue")
            }
            XCTAssertEqual(name, original.name)
            XCTAssertEqual(aisle, "B2")
            XCTAssertEqual(original.stock, 5)
        }
    }

    func testRenameAisleWrapsFailureWithRecoveryMessage() async {
        let repo = CoverageRepository()
        repo.medicinePages = [Page(items: [medicine()], cursor: nil, hasMore: false)]
        repo.applyError = StockError.message("écriture refusée")

        do {
            try await repo.renameAisle(from: "A1", to: "B2")
            XCTFail("Le renommage devait échouer")
        } catch {
            let message = userMessage(error)
            XCTAssertTrue(message.contains("Renommage interrompu"))
            XCTAssertTrue(message.contains("B2"))
            XCTAssertTrue(message.contains("écriture refusée"))
        }
        XCTAssertEqual(repo.createdAisles, ["B2"])
        XCTAssertTrue(repo.deletedAisles.isEmpty)
    }

    // MARK: - Thème (fonctions pures)

    func testThemeProvidesLightAndDarkPalettes() {
        XCTAssertEqual(MediStockTheme.backgroundColors(for: .light).count, 3)
        XCTAssertEqual(MediStockTheme.backgroundColors(for: .dark).count, 3)
        _ = MediStockTheme.supportingText(for: .light)
        _ = MediStockTheme.supportingText(for: .dark)
        _ = MediStockTheme.navigationColor(for: .light)
        _ = MediStockTheme.navigationColor(for: .dark)
        _ = MediStockTheme.tabColor(for: .light)
        _ = MediStockTheme.tabColor(for: .dark)
        _ = MediStockTheme.primary
        _ = MediStockTheme.logoStart
        _ = MediStockTheme.logoEnd
    }

    // MARK: - Helpers

    private func medicine(id: String = "m1", stock: Int = 5) -> Medicine {
        Medicine(id: id, name: "Test", stock: stock, aisle: "A1", version: 1)
    }

    private func entry(
        action: String,
        before: Medicine?,
        after: Medicine
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID().uuidString,
            medicineId: after.id,
            userId: "u1",
            userEmail: "test@example.com",
            action: action,
            before: before,
            after: after,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

private final class CoverageRepository: InventoryRepository {
    var medicinePages: [Page<Medicine>] = []
    var historyMedicineIDs: [String?] = []
    var createdAisles: [String] = []
    var deletedAisles: [String] = []
    var appliedCommands: [InventoryCommand] = []
    var applyError: Error?

    func medicines(_ filter: MedicineFilter, after: PageCursor?) async throws -> Page<Medicine> {
        if medicinePages.isEmpty {
            return Page(items: [], cursor: nil, hasMore: false)
        }
        return medicinePages.removeFirst()
    }

    func medicine(id: String) async throws -> Medicine {
        Medicine(id: id, name: "Test", stock: 5, aisle: "A1")
    }

    func history(medicineID: String?, after: PageCursor?) async throws -> Page<HistoryEntry> {
        historyMedicineIDs.append(medicineID)
        return Page(items: [], cursor: nil, hasMore: false)
    }

    func aisles(after: PageCursor?) async throws -> Page<Aisle> {
        Page(items: [], cursor: nil, hasMore: false)
    }

    func apply(_ command: InventoryCommand, operationID: String) async throws {
        appliedCommands.append(command)
        if let applyError { throw applyError }
    }

    func createAisle(_ name: String) async throws {
        createdAisles.append(name)
    }

    func deleteAisle(_ name: String) async throws {
        deletedAisles.append(name)
    }
}
