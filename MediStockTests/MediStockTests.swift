//
//  MediStockTests.swift
//  MediStockTests
//
//  Created by Vincent Saluzzo on 28/05/2024.
//


import Foundation
import XCTest
@testable import MediStock

final class MediStockTests: XCTestCase {

    // MARK: - Validations et modèles

    func testValidMedicineIsTrimmed() throws {
        let result = try MedicineValidation.validate(
            name: "  Doliprane  ",
            stock: 5,
            aisle: " Antalgiques "
        )

        XCTAssertEqual(result.name, "Doliprane")
        XCTAssertEqual(result.aisle, "Antalgiques")
    }

    func testInvalidNamesAreRejected() {
        let invalidNames = [
            "",
            "   ",
            "A\nB",
            "A\tB",
            String(repeating: "A", count: 81)
        ]

        for name in invalidNames {
            XCTAssertThrowsError(
                try MedicineValidation.validate(
                    name: name,
                    stock: 1,
                    aisle: "A1"
                )
            )
        }
    }

    func testInvalidAislesAreRejected() {
        let invalidAisles = [
            "",
            "  ",
            ".",
            "..",
            "A/B",
            "__interne__",
            "A\nB",
            String(repeating: "A", count: 61)
        ]

        for aisle in invalidAisles {
            XCTAssertThrowsError(
                try MedicineValidation.aisle(aisle)
            )
        }
    }

    func testMaximumLengthsAndQuantitiesAreAccepted() throws {
        let result = try MedicineValidation.validate(
            name: String(repeating: "A", count: 80),
            stock: 1_000_000,
            aisle: String(repeating: "B", count: 60)
        )

        XCTAssertEqual(result.name.count, 80)
        XCTAssertEqual(result.aisle.count, 60)

        XCTAssertNoThrow(
            try MedicineValidation.validate(
                name: "A",
                stock: 0,
                aisle: "B"
            )
        )
    }

    func testInvalidQuantitiesAreRejected() {
        for stock in [-1, 1_000_001] {
            XCTAssertThrowsError(
                try MedicineValidation.validate(
                    name: "A",
                    stock: stock,
                    aisle: "B"
                )
            )
        }
    }

    func testStockIncreasesDecreasesAndCanReachZero() throws {
        XCTAssertEqual(
            try MedicineValidation.adjustedStock(
                current: 5,
                delta: 1
            ),
            6
        )

        XCTAssertEqual(
            try MedicineValidation.adjustedStock(
                current: 5,
                delta: -1
            ),
            4
        )

        XCTAssertEqual(
            try MedicineValidation.adjustedStock(
                current: 1,
                delta: -1
            ),
            0
        )

        XCTAssertEqual(
            try MedicineValidation.adjustedStock(
                current: 5,
                delta: 0
            ),
            5
        )
    }

    func testStockBoundariesAndOverflowAreRejected() {
        let invalidChanges = [
            (0, -1),
            (1_000_000, 1),
            (Int.max, 1),
            (Int.min, -1)
        ]

        for (current, delta) in invalidChanges {
            XCTAssertThrowsError(
                try MedicineValidation.adjustedStock(
                    current: current,
                    delta: delta
                )
            )
        }
    }

    func testAllCommandsKeepTheMedicineID() {
        let medicine = reference()

        let commands: [InventoryCommand] = [
            .create(medicine),
            .edit(
                medicine,
                name: "Autre",
                aisle: "B1"
            ),
            .stock(
                id: medicine.id,
                delta: 1
            ),
            .archive(id: medicine.id)
        ]

        for command in commands {
            XCTAssertEqual(
                command.medicineID,
                medicine.id
            )
        }
    }

    func testHistoryDescribesCreationStockEditionAndArchive() {
        let old = reference(stock: 5)

        var next = reference(stock: 6)
        next.version = 2

        let created = event(
            action: "create",
            before: nil,
            after: old
        )

        XCTAssertEqual(created.title, "Création")
        XCTAssertTrue(created.details.contains("stock 5"))

        let stock = event(
            action: "stock",
            before: old,
            after: next
        )

        XCTAssertEqual(
            stock.title,
            "Changement de stock"
        )
        XCTAssertTrue(stock.details.contains("5 → 6"))
        XCTAssertEqual(
            stock.userEmail,
            "test@example.com"
        )

        next.name = "Nouveau nom"
        next.aisle = "B1"

        let edited = event(
            action: "edit",
            before: old,
            after: next
        )

        XCTAssertEqual(edited.title, "Modification")
        XCTAssertTrue(
            edited.details.contains("Nouveau nom")
        )
        XCTAssertTrue(
            edited.details.contains("A1 → B1")
        )

        next.archived = true

        let archived = event(
            action: "archive",
            before: old,
            after: next
        )

        XCTAssertEqual(
            archived.title,
            "Retrait du stock"
        )
        XCTAssertTrue(
            archived.details.contains("retiré")
        )

        XCTAssertEqual(
            event(
                action: "inconnu",
                before: old,
                after: next
            ).title,
            "Opération"
        )
    }

    func testKnownErrorsProduceUsefulMessages() {
        let errors: [StockError] = [
            .invalidName,
            .invalidAisle,
            .invalidStock,
            .missing,
            .conflict,
            .disconnected,
            .corrupted,
            .message("Message de test")
        ]

        for error in errors {
            XCTAssertFalse(
                userMessage(error).isEmpty
            )

            XCTAssertEqual(
                userMessage(error),
                error.localizedDescription
            )
        }

        XCTAssertEqual(
            userMessage(
                StockError.message("Message de test")
            ),
            "Message de test"
        )
    }

    func testFirebaseAndUnknownErrorsAreMapped() {
        // Les messages destinés aux utilisateurs peuvent évoluer,
        // mais ne doivent jamais exposer les codes ou domaines Firebase.
        for code in [7, 9, 14, 999] {
            let error = NSError(
                domain: "FIRFirestoreErrorDomain",
                code: code
            )
            let message = userMessage(error)

            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.contains("FIRFirestoreErrorDomain"))
            XCTAssertFalse(message.contains("NSError"))
            XCTAssertNotEqual(message, error.localizedDescription)
        }

        let unknown = NSError(domain: "AutreDomaine", code: 999)
        let message = userMessage(unknown)
        XCTAssertFalse(message.isEmpty)
        XCTAssertFalse(message.contains("AutreDomaine"))
    }

    // MARK: - Formulaires

    @MainActor
    func testCreateFormInitialValues() {
        let model = MedicineFormViewModel(
            initialAisle: "A1",
            repository: TestRepository()
        )

        XCTAssertNil(model.original)
        XCTAssertEqual(model.name, "")
        XCTAssertEqual(model.aisle, "A1")
        XCTAssertEqual(model.stockText, "0")
    }

    @MainActor
    func testInvalidFormsNeverWrite() async {
        let invalidInputs = [
            ("", "A1", "5"),
            ("Test", "", "5"),
            ("Test", "A1", "abc"),
            ("Test", "A1", "1.5"),
            ("Test", "A1", "-1")
        ]

        for (name, aisle, quantity) in invalidInputs {
            let repository = TestRepository()

            let model = MedicineFormViewModel(
                repository: repository
            )

            model.name = name
            model.aisle = aisle
            model.stockText = quantity

            let saved = await model.save()

            XCTAssertFalse(saved)
            XCTAssertTrue(repository.writes.isEmpty)
            XCTAssertNotNil(model.errorMessage)
            XCTAssertFalse(model.isSaving)
        }
    }

    @MainActor
    func testCreateFormWritesCleanValues() async {
        let repository = TestRepository()
        let model = validForm(repository)

        model.name = "  Test  "
        model.aisle = " A1 "

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(repository.writes.count, 1)

        guard case .create(let value)? =
            repository.writes.first?.command else {
            return XCTFail("Création attendue")
        }

        XCTAssertEqual(value.name, "Test")
        XCTAssertEqual(value.aisle, "A1")
        XCTAssertEqual(value.stock, 5)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testEditFormDoesNotOverwriteTheStock() async {
        let repository = TestRepository()
        let old = reference(stock: 12)

        let model = MedicineFormViewModel(
            medicine: old,
            repository: repository
        )

        XCTAssertEqual(model.stockText, "12")

        model.name = "Nouveau"
        model.aisle = "B1"

        // Ce champ ne doit pas modifier le stock
        // lors de l'édition des informations de la fiche.
        model.stockText = "999"

        let saved = await model.save()

        XCTAssertTrue(saved)

        guard case .edit(
            let original,
            let name,
            let aisle
        )? = repository.writes.first?.command else {
            return XCTFail("Modification attendue")
        }

        XCTAssertEqual(original, old)
        XCTAssertEqual(original.stock, 12)
        XCTAssertEqual(name, "Nouveau")
        XCTAssertEqual(aisle, "B1")
    }

    @MainActor
    func testFormRetryReusesOperationIDUntilInputChanges() async throws {
        let repository = TestRepository()
        repository.writeError =
            StockError.message("Échec simulé")

        let model = validForm(repository)

        let first = await model.save()

        XCTAssertFalse(first)
        XCTAssertNotNil(model.errorMessage)

        let firstID = try XCTUnwrap(
            repository.writes.first?.operationID
        )

        let second = await model.save()

        XCTAssertFalse(second)
        XCTAssertEqual(
            repository.writes.last?.operationID,
            firstID
        )

        model.name = "Autre référence"
        repository.writeError = nil

        let recovered = await model.save()

        XCTAssertTrue(recovered)
        XCTAssertNotEqual(
            repository.writes.last?.operationID,
            firstID
        )
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testFormRejectsDoubleSubmissionWhileSaving() async {
        let repository = TestRepository()
        let gate = TestGate()

        let started = expectation(
            description: "Enregistrement commencé"
        )

        repository.onWrite = {
            started.fulfill()
            await gate.wait()
        }

        let model = validForm(repository)

        let first = Task {
            await model.save()
        }

        await fulfillment(
            of: [started],
            timeout: 2
        )

        XCTAssertTrue(model.isSaving)

        let duplicate = await model.save()

        XCTAssertFalse(duplicate)
        XCTAssertEqual(repository.writes.count, 1)

        gate.release()

        let completed = await first.value

        XCTAssertTrue(completed)
        XCTAssertFalse(model.isSaving)
    }

    // MARK: - Pagination et listes

    @MainActor
    func testPaginationAppendsDeduplicatesAndStops() async {
        let model = PagedViewModel<Medicine>()

        await model.load(reset: true) { _ in
            Page(
                items: [reference(id: "a")],
                cursor: nil,
                hasMore: true
            )
        }

        await model.load(reset: false) { _ in
            Page(
                items: [
                    reference(id: "a"),
                    reference(id: "b")
                ],
                cursor: nil,
                hasMore: false
            )
        }

        XCTAssertEqual(
            model.items.map(\.id),
            ["a", "b"]
        )
        XCTAssertFalse(model.hasMore)

        var unexpectedFetch = false

        await model.load(reset: false) { _ in
            unexpectedFetch = true

            return Page(
                items: [],
                cursor: nil,
                hasMore: false
            )
        }

        XCTAssertFalse(unexpectedFetch)

        await model.load(reset: true) { _ in
            Page(
                items: [reference(id: "c")],
                cursor: nil,
                hasMore: false
            )
        }

        XCTAssertEqual(
            model.items.map(\.id),
            ["c"]
        )
    }

    @MainActor
    func testPaginationDisplaysErrorThenRecovers() async {
        let model = PagedViewModel<Medicine>()

        await model.load(reset: true) { _ in
            throw StockError.message(
                "Lecture impossible"
            )
        }

        XCTAssertEqual(
            model.errorMessage,
            "Lecture impossible"
        )
        XCTAssertFalse(model.isLoading)

        await model.load(reset: true) { _ in
            Page(
                items: [reference()],
                cursor: nil,
                hasMore: false
            )
        }

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.items.count, 1)
    }

    @MainActor
    func testOldResponseCannotReplaceNewSearchResults() async {
        let model = PagedViewModel<Medicine>()
        let gate = TestGate()

        let started = expectation(
            description: "Ancienne lecture commencée"
        )

        let old = Task {
            await model.load(reset: true) { _ in
                started.fulfill()
                await gate.wait()

                return Page(
                    items: [reference(id: "ancien")],
                    cursor: nil,
                    hasMore: false
                )
            }
        }

        await fulfillment(
            of: [started],
            timeout: 2
        )

        XCTAssertTrue(model.isLoading)

        var duplicateFetch = false

        await model.load(reset: false) { _ in
            duplicateFetch = true

            return Page(
                items: [],
                cursor: nil,
                hasMore: false
            )
        }

        XCTAssertFalse(duplicateFetch)

        await model.load(reset: true) { _ in
            Page(
                items: [reference(id: "nouveau")],
                cursor: nil,
                hasMore: false
            )
        }

        gate.release()
        await old.value

        XCTAssertEqual(
            model.items.map(\.id),
            ["nouveau"]
        )
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testCancelledLoadingDoesNotDisplayAnError() async {
        let model = PagedViewModel<Medicine>()
        let gate = TestGate()

        let started = expectation(
            description: "Lecture commencée"
        )

        let task = Task {
            await model.load(reset: true) { _ in
                started.fulfill()
                await gate.wait()

                return Page(
                    items: [reference()],
                    cursor: nil,
                    hasMore: false
                )
            }
        }

        await fulfillment(
            of: [started],
            timeout: 2
        )

        task.cancel()
        gate.release()
        await task.value

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testMedicinesForwardFilterAndLoadFollowingPage() async {
        let repository = TestRepository()

        repository.medicinePages = [
            Page(
                items: [reference(id: "a")],
                cursor: nil,
                hasMore: true
            ),
            Page(
                items: [reference(id: "b")],
                cursor: nil,
                hasMore: false
            )
        ]

        let model = MedicineStockViewModel(
            aisle: "A1",
            repository: repository
        )

        model.search = "dol"
        model.sort = .stock

        await model.reload(debounce: true)
        await model.loadMore()

        XCTAssertEqual(repository.filters.count, 2)

        XCTAssertEqual(
            repository.filters.first?.aisle,
            "A1"
        )

        XCTAssertEqual(
            repository.filters.first?.prefix,
            "dol"
        )

        XCTAssertEqual(
            repository.filters.first?.sort,
            .stock
        )

        XCTAssertEqual(
            model.items.map(\.id),
            ["a", "b"]
        )
    }

    // MARK: - Fiche

    @MainActor
    func testDetailLoadsAndReportsReadFailure() async {
        let repository = TestRepository()

        let model = MedicineDetailViewModel(
            id: "m1",
            repository: repository
        )

        await model.reload()

        XCTAssertEqual(model.medicine?.id, "m1")
        XCTAssertFalse(model.isLoading)

        repository.readError =
            StockError.message("Lecture échouée")

        await model.reload()

        XCTAssertEqual(
            model.errorMessage,
            "Lecture échouée"
        )
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testDetailChangesStockAndRefreshes() async {
        let repository = TestRepository()
        repository.loadedMedicine = reference(stock: 6)

        let model = MedicineDetailViewModel(
            id: "m1",
            repository: repository
        )

        let success = await model.changeStock(1)

        XCTAssertTrue(success)

        XCTAssertEqual(
            repository.writes.first?.command,
            .stock(id: "m1", delta: 1)
        )

        XCTAssertEqual(model.medicine?.stock, 6)
        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testDetailArchiveAndWriteFailure() async {
        let repository = TestRepository()

        var archived = reference()
        archived.archived = true

        repository.loadedMedicine = archived

        let model = MedicineDetailViewModel(
            id: "m1",
            repository: repository
        )

        let success = await model.archive()

        XCTAssertTrue(success)

        XCTAssertEqual(
            repository.writes.first?.command,
            .archive(id: "m1")
        )

        XCTAssertEqual(
            model.medicine?.archived,
            true
        )

        repository.writeError =
            StockError.message("Écriture refusée")

        let failed = await model.changeStock(-1)

        XCTAssertFalse(failed)

        XCTAssertEqual(
            model.errorMessage,
            "Écriture refusée"
        )

        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testDetailRetryKeepsOperationID() async throws {
        let repository = TestRepository()
        repository.writeError = StockError.message("Réseau")

        let model = MedicineDetailViewModel(
            id: "m1",
            repository: repository
        )

        let first = await model.changeStock(1)

        XCTAssertFalse(first)

        let id = try XCTUnwrap(
            repository.writes.first?.operationID
        )

        repository.writeError = nil

        let second = await model.changeStock(1)

        XCTAssertTrue(second)

        XCTAssertEqual(
            repository.writes.last?.operationID,
            id
        )
    }

    // MARK: - Rayons et historique

    @MainActor
    func testAislesLoadCreateAndDelete() async {
        let repository = TestRepository()

        repository.aislePages = [
            Page(
                items: [Aisle(id: "A1", count: 0)],
                cursor: nil,
                hasMore: true
            ),
            Page(
                items: [Aisle(id: "B1", count: 0)],
                cursor: nil,
                hasMore: false
            )
        ]

        let model = AislesViewModel(
            repository: repository
        )

        await model.reload()
        await model.loadMore()

        XCTAssertEqual(
            model.items.map(\.id),
            ["A1", "B1"]
        )

        await model.save(name: "C1")

        XCTAssertEqual(
            repository.createdAisles,
            ["C1"]
        )

        await model.save(
            name: "C1",
            deleting: true
        )

        XCTAssertEqual(
            repository.deletedAisles,
            ["C1"]
        )

        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testAisleFailureRemainsVisibleAfterRefresh() async {
        let repository = TestRepository()

        repository.deleteError =
            StockError.message("Rayon occupé")

        let model = AislesViewModel(
            repository: repository
        )

        await model.save(
            name: "A1",
            deleting: true
        )

        XCTAssertEqual(
            model.errorMessage,
            "Rayon occupé"
        )

        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testRenameTransfersMedicineWithoutChangingItsStock() async {
        let repository = TestRepository()
        let medicine = reference(stock: 17)

        repository.medicinePages = [
            Page(
                items: [medicine],
                cursor: nil,
                hasMore: false
            )
        ]

        let model = AislesViewModel(
            repository: repository
        )

        await model.rename(
            from: "A1",
            to: " B1 "
        )

        XCTAssertEqual(
            repository.createdAisles,
            ["B1"]
        )

        XCTAssertEqual(
            repository.deletedAisles,
            ["A1"]
        )

        XCTAssertEqual(
            repository.writes.first?.command,
            .edit(
                medicine,
                name: medicine.name,
                aisle: "B1"
            )
        )

        XCTAssertNil(model.errorMessage)
    }

    func testRenameWithUnchangedNameDoesNothing() async throws {
        let repository = TestRepository()

        try await repository.renameAisle(
            from: "A1",
            to: " A1 "
        )

        XCTAssertTrue(repository.filters.isEmpty)
        XCTAssertTrue(repository.createdAisles.isEmpty)
        XCTAssertTrue(repository.deletedAisles.isEmpty)
    }

    func testInterruptedRenameDoesNotDeleteOriginalAisle() async {
        let repository = TestRepository()

        repository.medicinePages = [
            Page(
                items: [reference()],
                cursor: nil,
                hasMore: false
            )
        ]

        repository.writeError =
            StockError.message("Réseau indisponible")

        do {
            try await repository.renameAisle(
                from: "A1",
                to: "B1"
            )

            XCTFail("Une erreur était attendue")

        } catch {
            XCTAssertTrue(
                error.localizedDescription.contains(
                    "Renommage interrompu"
                )
            )
        }

        XCTAssertEqual(
            repository.createdAisles,
            ["B1"]
        )

        XCTAssertTrue(
            repository.deletedAisles.isEmpty
        )
    }

    @MainActor
    func testHistoryLoadsItsMedicineAndFollowingPages() async {
        let repository = TestRepository()

        repository.historyPages = [
            Page(
                items: [event(id: "e1")],
                cursor: nil,
                hasMore: true
            ),
            Page(
                items: [event(id: "e2")],
                cursor: nil,
                hasMore: false
            )
        ]

        let model = HistoryViewModel(
            medicineID: "m1",
            repository: repository
        )

        await model.reload()
        await model.loadMore()

        XCTAssertEqual(
            repository.historyQueries.count,
            2
        )

        XCTAssertEqual(
            repository.historyQueries.first ?? nil,
            "m1"
        )

        XCTAssertEqual(
            model.items.map(\.id),
            ["e1", "e2"]
        )
    }

    @MainActor
    func testGlobalHistoryReportsAnError() async {
        let repository = TestRepository()

        repository.readError =
            StockError.message("Historique indisponible")

        let model = HistoryViewModel(
            repository: repository
        )

        await model.reload()

        XCTAssertNil(
            repository.historyQueries.first ?? nil
        )

        XCTAssertEqual(
            model.errorMessage,
            "Historique indisponible"
        )

        XCTAssertFalse(model.isLoading)
    }
}

// MARK: - Données fixes pour les tests

private func reference(
    id: String = "m1",
    stock: Int = 5
) -> Medicine {
    Medicine(
        id: id,
        name: "Test",
        stock: stock,
        aisle: "A1",
        archived: false,
        version: 1
    )
}

private func event(
    id: String = "e1",
    action: String = "stock",
    before: Medicine? = reference(stock: 5),
    after: Medicine = reference(stock: 6)
) -> HistoryEntry {
    HistoryEntry(
        id: id,
        medicineId: "m1",
        userId: "user-test",
        userEmail: "test@example.com",
        action: action,
        before: before,
        after: after,
        timestamp: Date(
            timeIntervalSince1970: 1_700_000_000
        )
    )
}

@MainActor
private func validForm(
    _ repository: TestRepository
) -> MedicineFormViewModel {
    let model = MedicineFormViewModel(
        repository: repository
    )

    model.name = "Test"
    model.aisle = "A1"
    model.stockText = "5"

    return model
}

// MARK: - Dépôt simulé

// Ce dépôt enregistre les demandes sans appeler Firebase.
// Il ne réimplémente ni les transactions ni les règles serveur.
private final class TestRepository: InventoryRepository {
    var medicinePages: [Page<Medicine>] = []
    var aislePages: [Page<Aisle>] = []
    var historyPages: [Page<HistoryEntry>] = []

    var loadedMedicine = reference()

    var readError: Error?
    var writeError: Error?
    var deleteError: Error?

    var onWrite: (() async -> Void)?

    var filters: [MedicineFilter] = []
    var historyQueries: [String?] = []

    var writes: [
        (
            command: InventoryCommand,
            operationID: String
        )
    ] = []

    var createdAisles: [String] = []
    var deletedAisles: [String] = []

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine> {
        filters.append(filter)

        if let readError {
            throw readError
        }

        return medicinePages.isEmpty
            ? Page(
                items: [],
                cursor: nil,
                hasMore: false
            )
            : medicinePages.removeFirst()
    }

    func medicine(
        id: String
    ) async throws -> Medicine {
        if let readError {
            throw readError
        }

        return loadedMedicine
    }

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        historyQueries.append(medicineID)

        if let readError {
            throw readError
        }

        return historyPages.isEmpty
            ? Page(
                items: [],
                cursor: nil,
                hasMore: false
            )
            : historyPages.removeFirst()
    }

    func aisles(
        after: PageCursor?
    ) async throws -> Page<Aisle> {
        if let readError {
            throw readError
        }

        return aislePages.isEmpty
            ? Page(
                items: [],
                cursor: nil,
                hasMore: false
            )
            : aislePages.removeFirst()
    }

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws {
        writes.append(
            (command, operationID)
        )

        if let onWrite {
            await onWrite()
        }

        if let writeError {
            throw writeError
        }
    }

    func createAisle(
        _ name: String
    ) async throws {
        createdAisles.append(name)
    }

    func deleteAisle(
        _ name: String
    ) async throws {
        if let deleteError {
            throw deleteError
        }

        deletedAisles.append(name)
    }
}

// MARK: - Synchronisation déterministe des tests

// Permet de suspendre une opération simulée,
// sans dépendre d'un délai réseau arbitraire.
@MainActor
private final class TestGate {
    private var isOpen = false

    private var continuation:
        CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation {
            continuation = $0
        }
    }

    func release() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
