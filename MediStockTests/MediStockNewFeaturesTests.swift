//
//  MediStockNewFeaturesTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 31/10/2026.
//

import Foundation
import XCTest
@testable import MediStock


final class MediStockNewFeaturesTests: XCTestCase {

    func testAllMedicineSortOptionsExist() {
        XCTAssertEqual(
            MedicineSort.allCases,
            [.name, .stock, .stockDescending]
        )
        XCTAssertEqual(Set(MedicineSort.allCases.map(\.id)).count, 3)
        XCTAssertNotEqual(MedicineSort.stock, MedicineSort.stockDescending)
    }

    func testMedicineFilterPreservesDescendingChoice() {
        let filter = MedicineFilter(
            aisle: "Antalgiques",
            prefix: "",
            sort: .stockDescending
        )
        XCTAssertEqual(filter.aisle, "Antalgiques")
        XCTAssertEqual(filter.sort, .stockDescending)
    }

    func testHistorySortDirections() {
        XCTAssertTrue(HistorySort.newest.descending)
        XCTAssertFalse(HistorySort.oldest.descending)
        XCTAssertEqual(HistorySort.allCases.count, 2)
    }

    func testDefaultHistoryFilterDoesNotActivateAdvancedSearch() {
        let filter = HistoryFilter()
        XCTAssertNil(filter.medicineID)
        XCTAssertNil(filter.day)
        XCTAssertFalse(filter.usesAdvancedFilters)
        XCTAssertEqual(filter.sort, .newest)
    }

    func testHistoryFilterActivatesAdvancedSearchForEachDimension() {
        var filter = HistoryFilter()

        filter.userEmail = "historique@example.com"
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter.userEmail = "   "
        XCTAssertFalse(filter.usesAdvancedFilters)

        filter.medicineName = "Doliprane"
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter.medicineName = " "
        XCTAssertFalse(filter.usesAdvancedFilters)

        filter.aisle = "Antalgiques"
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter.aisle = ""

        filter.day = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(filter.usesAdvancedFilters)
        filter.day = nil

        filter.sort = .oldest
        XCTAssertTrue(filter.usesAdvancedFilters)
    }

    func testHistoryFilterHoldsCombinedSelection() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let filter = HistoryFilter(
            medicineID: "m-123",
            userEmail: "alice@example.com",
            medicineName: "Doliprane",
            aisle: "Antalgiques",
            day: day,
            sort: .oldest
        )

        XCTAssertEqual(filter.medicineID, "m-123")
        XCTAssertEqual(filter.userEmail, "alice@example.com")
        XCTAssertEqual(filter.medicineName, "Doliprane")
        XCTAssertEqual(filter.aisle, "Antalgiques")
        XCTAssertEqual(filter.day, day)
        XCTAssertEqual(filter.sort, .oldest)
    }

    @MainActor
    func testHistoryViewModelPassesSelectedFiltersToRepository() async {
        let repository = HistoryFilterSpy()
        let model = HistoryViewModel(repository: repository)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = HistoryFilter(
            medicineID: "m-123",
            userEmail: "alice@example.com",
            medicineName: "",
            aisle: "Antalgiques",
            day: day,
            sort: .oldest
        )

        model.filter = expected
        await model.reload()

        XCTAssertEqual(repository.receivedFilters, [expected])
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testHistoryViewModelPropagatesServerReadError() async {
        let repository = HistoryFilterSpy()
        repository.readError = StockError.message("Lecture indisponible")
        let model = HistoryViewModel(repository: repository)

        await model.reload()

        XCTAssertEqual(model.errorMessage, "Lecture indisponible")
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testAuthorsViewModelLoadsPreviousAuthorsFromRepository() async {
        let repository = HistoryAuthorStub(
            emails: ["alice@example.com", "bob@example.com"]
        )
        let model = HistoryAuthorsViewModel(repository: repository)

        XCTAssertFalse(model.hasLoaded)
        await model.reload()
        XCTAssertEqual(model.emails, ["alice@example.com", "bob@example.com"])
        XCTAssertTrue(model.hasLoaded)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testAuthorsViewModelReportsReadErrorWithoutFakeResults() async {
        let repository = HistoryAuthorStub(emails: [], shouldFail: true)
        let model = HistoryAuthorsViewModel(repository: repository)

        await model.reload()

        XCTAssertTrue(model.emails.isEmpty)
        XCTAssertFalse(model.hasLoaded)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testSessionSignInRejectsEmptyCredentialsBeforeNetworkCall() async {
        let session = SessionStore()
        do {
            try await session.signIn(email: "", password: "")
            XCTFail("La connexion vide doit être rejetée")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Renseigne"))
        }
    }

    @MainActor
    func testSessionSignupRejectsInvalidEmailBeforeNetworkCall() async {
        let session = SessionStore()
        do {
            try await session.signUp(
                email: "invalide",
                password: "abcdef",
                confirmation: "abcdef"
            )
            XCTFail("L'email invalide doit être rejeté")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("format"))
        }
    }

    @MainActor
    func testSessionSignupRejectsShortPasswordBeforeNetworkCall() async {
        let session = SessionStore()
        do {
            try await session.signUp(
                email: "test@example.com",
                password: "123",
                confirmation: "123"
            )
            XCTFail("Le mot de passe court doit être rejeté")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("6 caractères"))
        }
    }

    @MainActor
    func testSessionSignupRejectsPasswordMismatchBeforeNetworkCall() async {
        let session = SessionStore()
        do {
            try await session.signUp(
                email: "test@example.com",
                password: "abcdef",
                confirmation: "ghijkl"
            )
            XCTFail("Les mots de passe différents doivent être rejetés")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("ne correspondent pas"))
        }
    }

    @MainActor
    func testSessionResetRequiresEmailBeforeNetworkCall() async {
        let session = SessionStore()
        do {
            try await session.resetPassword(email: "")
            XCTFail("La demande sans adresse doit être rejetée")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("adresse email"))
        }
    }
}

private final class HistoryFilterSpy: InventoryRepository {
    var receivedFilters: [HistoryFilter] = []
    var readError: Error?

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine> {
        Page(items: [], cursor: nil, hasMore: false)
    }

    func medicine(id: String) async throws -> Medicine {
        throw StockError.missing
    }

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        // Utilisée par les anciens tests ; ne doit pas être invoquée ici.
        throw StockError.message("Ancienne méthode invoquée")
    }

    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        receivedFilters.append(filter)
        if let readError { throw readError }
        return Page(items: [], cursor: nil, hasMore: false)
    }

    func aisles(after: PageCursor?) async throws -> Page<Aisle> {
        Page(items: [], cursor: nil, hasMore: false)
    }

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws {}

    func createAisle(_ name: String) async throws {}
    func deleteAisle(_ name: String) async throws {}
}

private actor HistoryAuthorStub: HistoryAuthorsRepository {
    let emails: [String]
    let shouldFail: Bool

    init(emails: [String], shouldFail: Bool = false) {
        self.emails = emails
        self.shouldFail = shouldFail
    }

    func allAuthorEmails() async throws -> [String] {
        if shouldFail {
            throw StockError.message("Auteurs indisponibles")
        }
        return emails
    }
}
