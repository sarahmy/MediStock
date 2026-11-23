//
//  MediStockMedicineDetailExtraTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import XCTest
@testable import MediStock

final class MediStockMedicineDetailExtraTests: XCTestCase {

    // MARK: - Chargement et erreurs

    @MainActor
    func testInitialStateAndFirstReload() async {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        XCTAssertNil(model.medicine)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.isSaving)

        await model.reload()

        XCTAssertEqual(model.medicine?.id, "m-test")
        XCTAssertEqual(model.medicine?.stock, 10)
        XCTAssertEqual(repository.readCalls, 1)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testSuccessfulReloadClearsAnEarlierReadError() async {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        repository.readError = StockError.message(
            "Lecture interrompue"
        )

        await model.reload()

        XCTAssertEqual(
            model.errorMessage,
            "Lecture interrompue"
        )
        XCTAssertNil(model.medicine)

        repository.readError = nil
        await model.reload()

        XCTAssertEqual(model.medicine?.stock, 10)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    // MARK: - Requêtes concurrentes et annulation

    @MainActor
    func testCancelledReloadDoesNotReplacePreviousMedicine() async {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        await model.reload()
        XCTAssertEqual(model.medicine?.stock, 10)

        let gate = MedicineDetailExtraGate()
        let started = expectation(
            description: "Lecture différée commencée"
        )

        repository.readHandler = { _ in
            started.fulfill()
            await gate.wait()

            return medicineDetailSample(stock: 99)
        }

        let task = Task {
            await model.reload()
        }

        await fulfillment(
            of: [started],
            timeout: 5
        )

        XCTAssertTrue(model.isLoading)

        task.cancel()
        gate.release()

        await task.value

        XCTAssertEqual(model.medicine?.stock, 10)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testOldResponseCannotReplaceNewerMedicine() async {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        let gate = MedicineDetailExtraGate()
        let started = expectation(
            description: "Ancienne lecture commencée"
        )

        repository.readHandler = { call in
            if call == 1 {
                started.fulfill()
                await gate.wait()

                return medicineDetailSample(stock: 1)
            }

            return medicineDetailSample(stock: 20)
        }

        let oldTask = Task {
            await model.reload()
        }

        await fulfillment(
            of: [started],
            timeout: 5
        )

        await model.reload()

        XCTAssertEqual(model.medicine?.stock, 20)
        XCTAssertFalse(model.isLoading)

        gate.release()
        await oldTask.value

        XCTAssertEqual(repository.readCalls, 2)
        XCTAssertEqual(model.medicine?.stock, 20)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testLateFailureDoesNotHideNewerSuccess() async {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        let gate = MedicineDetailExtraGate()
        let started = expectation(
            description: "Ancienne lecture commencée"
        )

        repository.readHandler = { call in
            if call == 1 {
                started.fulfill()
                await gate.wait()

                throw StockError.message(
                    "Ancienne erreur"
                )
            }

            return medicineDetailSample(stock: 30)
        }

        let oldTask = Task {
            await model.reload()
        }

        await fulfillment(
            of: [started],
            timeout: 5
        )

        await model.reload()

        gate.release()
        await oldTask.value

        XCTAssertEqual(model.medicine?.stock, 30)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    // MARK: - Écritures et identifiants d'opération

    @MainActor
    func testSecondCommandIsRejectedWhileSaving() async {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        let gate = MedicineDetailExtraGate()
        let started = expectation(
            description: "Écriture commencée"
        )

        repository.writeHandler = {
            started.fulfill()
            await gate.wait()
        }

        let firstTask = Task {
            await model.changeStock(1)
        }

        await fulfillment(
            of: [started],
            timeout: 5
        )

        XCTAssertTrue(model.isSaving)

        let duplicate = await model.archive()

        XCTAssertFalse(duplicate)
        XCTAssertEqual(repository.writes.count, 1)

        gate.release()

        let firstSucceeded = await firstTask.value

        XCTAssertTrue(firstSucceeded)
        XCTAssertFalse(model.isSaving)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testChangedCommandGetsNewIDAndRetryKeepsThatID() async throws {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        repository.writeError = StockError.message(
            "Réseau indisponible"
        )

        let firstSucceeded = await model.changeStock(1)

        XCTAssertFalse(firstSucceeded)

        let firstID = try XCTUnwrap(
            repository.writes.first?.operationID
        )

        let secondSucceeded = await model.archive()

        XCTAssertFalse(secondSucceeded)

        let archiveID = try XCTUnwrap(
            repository.writes.last?.operationID
        )

        XCTAssertNotEqual(archiveID, firstID)

        repository.writeError = nil

        let retrySucceeded = await model.archive()

        XCTAssertTrue(retrySucceeded)
        XCTAssertEqual(repository.writes.count, 3)
        XCTAssertEqual(
            repository.writes.last?.operationID,
            archiveID
        )
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testSuccessfulCommandDoesNotReuseItsOperationID() async throws {
        let repository = MedicineDetailExtraRepository()
        let model = MedicineDetailViewModel(
            id: "m-test",
            repository: repository
        )

        let firstSucceeded = await model.changeStock(1)
        let secondSucceeded = await model.changeStock(1)

        XCTAssertTrue(firstSucceeded)
        XCTAssertTrue(secondSucceeded)
        XCTAssertEqual(repository.writes.count, 2)

        let firstID = try XCTUnwrap(
            repository.writes.first?.operationID
        )

        let secondID = try XCTUnwrap(
            repository.writes.last?.operationID
        )

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertNil(model.errorMessage)
    }
}

// MARK: - Données fixes pour les tests

private func medicineDetailSample(
    stock: Int = 10
) -> Medicine {

    Medicine(
        id: "m-test",
        name: "Paracétamol",
        stock: stock,
        aisle: "A1",
        archived: false,
        version: 1
    )
}

// MARK: - Repository simulé sans Firebase

@MainActor
private final class MedicineDetailExtraRepository:
    InventoryRepository {

    private(set) var readCalls = 0

    private(set) var writes: [
        (
            command: InventoryCommand,
            operationID: String
        )
    ] = []

    var readError: Error?
    var writeError: Error?

    var readHandler: (
        (Int) async throws -> Medicine
    )?

    var writeHandler: (
        () async throws -> Void
    )?

    func medicine(
        id: String
    ) async throws -> Medicine {

        readCalls += 1

        if let readHandler {
            return try await readHandler(readCalls)
        }

        if let readError {
            throw readError
        }

        return medicineDetailSample()
    }

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws {

        writes.append(
            (command, operationID)
        )

        if let writeHandler {
            try await writeHandler()
        }

        if let writeError {
            throw writeError
        }
    }

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine> {

        throw StockError.message(
            "Appel inattendu : medicines"
        )
    }

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {

        throw StockError.message(
            "Appel inattendu : history"
        )
    }

    func aisles(
        after: PageCursor?
    ) async throws -> Page<Aisle> {

        throw StockError.message(
            "Appel inattendu : aisles"
        )
    }

    func createAisle(
        _ name: String
    ) async throws {

        throw StockError.message(
            "Appel inattendu : createAisle"
        )
    }

    func deleteAisle(
        _ name: String
    ) async throws {

        throw StockError.message(
            "Appel inattendu : deleteAisle"
        )
    }
}

// MARK: - Synchronisation des tests asynchrones

@MainActor
private final class MedicineDetailExtraGate {

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
