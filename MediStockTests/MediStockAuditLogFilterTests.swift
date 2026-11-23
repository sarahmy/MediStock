//
//  MediStockAuditLogFilterTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import XCTest
@testable import MediStock

final class MediStockAuditLogFilterTests: XCTestCase {

    @MainActor
    func testDefaultStateUsesDateAndNewestSort() {
        let model = AuditLogFilterViewModel()

        XCTAssertEqual(model.mode, .date)
        XCTAssertEqual(model.sort, .newest)
        XCTAssertNil(model.selectedDay)
        XCTAssertEqual(model.medicineID, "")
        XCTAssertEqual(model.selectedMedicineName, "")
        XCTAssertNil(model.historyFilter.day)
        XCTAssertNil(model.historyFilter.medicineID)
        XCTAssertEqual(model.historyFilter.sort, .newest)
        XCTAssertEqual(
            model.selectedMedicineLabel(from: []),
            "Tous les médicaments"
        )
    }

    @MainActor
    func testSelectingDayNormalizesToStartOfDay() {
        let model = AuditLogFilterViewModel()
        let selected = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = Calendar.current.startOfDay(for: selected)

        model.selectDay(selected)

        XCTAssertEqual(model.selectedDay, expected)
        XCTAssertEqual(model.historyFilter.day, expected)
        XCTAssertNil(model.historyFilter.medicineID)
    }

    @MainActor
    func testClearingDayRemovesDateFilter() {
        let model = AuditLogFilterViewModel()
        model.selectDay(Date(timeIntervalSince1970: 1_700_000_000))

        model.selectDay(nil)

        XCTAssertNil(model.selectedDay)
        XCTAssertNil(model.historyFilter.day)
    }

    @MainActor
    func testChangingToMedicineModeClearsDate() {
        let model = AuditLogFilterViewModel()
        model.selectDay(Date(timeIntervalSince1970: 1_700_000_000))

        model.selectMode(.medicine)

        XCTAssertEqual(model.mode, .medicine)
        XCTAssertNil(model.selectedDay)
        XCTAssertNil(model.historyFilter.day)
        XCTAssertNil(model.historyFilter.medicineID)
    }

    @MainActor
    func testSelectingMedicineBuildsHistoryFilter() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)

        model.selectMedicine(
            .init(id: "m42", name: "Doliprane")
        )

        XCTAssertEqual(model.medicineID, "m42")
        XCTAssertEqual(model.selectedMedicineName, "Doliprane")
        XCTAssertEqual(model.historyFilter.medicineID, "m42")
        XCTAssertNil(model.historyFilter.day)
        XCTAssertEqual(
            model.selectedMedicineLabel(from: []),
            "Doliprane"
        )
    }

    @MainActor
    func testClearingMedicineSelectionShowsAllMedicines() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)
        model.selectMedicine(.init(id: "m42", name: "Doliprane"))

        model.selectMedicine(nil)

        XCTAssertEqual(model.medicineID, "")
        XCTAssertEqual(model.selectedMedicineName, "")
        XCTAssertNil(model.historyFilter.medicineID)
        XCTAssertEqual(
            model.selectedMedicineLabel(from: []),
            "Tous les médicaments"
        )
    }

    @MainActor
    func testReturningToDateModeClearsMedicineSelection() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)
        model.selectMedicine(.init(id: "m42", name: "Doliprane"))

        model.selectMode(.date)

        XCTAssertEqual(model.mode, .date)
        XCTAssertEqual(model.medicineID, "")
        XCTAssertEqual(model.selectedMedicineName, "")
        XCTAssertNil(model.historyFilter.medicineID)
    }

    @MainActor
    func testSelectingSameModeKeepsCurrentSelection() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)
        model.selectMedicine(.init(id: "m42", name: "Doliprane"))

        model.selectMode(.medicine)

        XCTAssertEqual(model.medicineID, "m42")
        XCTAssertEqual(model.selectedMedicineName, "Doliprane")
    }

    @MainActor
    func testChangingSortIsForwardedToHistoryFilter() throws {
        let model = AuditLogFilterViewModel()
        let alternative = try XCTUnwrap(
            HistorySort.allCases.first { $0 != .newest }
        )

        model.selectSort(alternative)
        model.selectMode(.medicine)

        XCTAssertEqual(model.sort, alternative)
        XCTAssertEqual(model.historyFilter.sort, alternative)
    }

    @MainActor
    func testMedicineChoicesAreUniqueSortedAndKeepFirstName() {
        let model = AuditLogFilterViewModel()
        let entries = [
            historyEntry(id: "e1", medicineID: "m2", name: "Zyrtec"),
            historyEntry(id: "e2", medicineID: "m1", name: "Advil"),
            historyEntry(id: "e3", medicineID: "m2", name: "Ancien nom")
        ]

        let choices = model.medicines(from: entries)

        XCTAssertEqual(choices.map(\.id), ["m1", "m2"])
        XCTAssertEqual(choices.map(\.name), ["Advil", "Zyrtec"])
    }

    @MainActor
    func testSelectedMedicineAbsentFromLoadedPagesStaysInMenu() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)
        model.selectMedicine(.init(id: "m3", name: "Bepanthen"))
        let entries = [
            historyEntry(id: "e1", medicineID: "m1", name: "Advil"),
            historyEntry(id: "e2", medicineID: "m2", name: "Zyrtec")
        ]

        let choices = model.medicines(from: entries)

        XCTAssertEqual(choices.map(\.id), ["m1", "m3", "m2"])
        XCTAssertEqual(
            choices.map(\.name),
            ["Advil", "Bepanthen", "Zyrtec"]
        )
    }

    @MainActor
    func testSelectedMedicineLabelPrefersNameFromLoadedHistory() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)
        model.selectMedicine(.init(id: "m1", name: "Ancien intitulé"))
        let entries = [
            historyEntry(
                id: "e1",
                medicineID: "m1",
                name: "Nom dans l'historique"
            )
        ]

        XCTAssertEqual(
            model.selectedMedicineLabel(from: entries),
            "Nom dans l'historique"
        )
    }

    @MainActor
    func testSelectedMedicineWithoutNameFallsBackToItsID() {
        let model = AuditLogFilterViewModel()
        model.selectMode(.medicine)
        model.selectMedicine(.init(id: "m-sans-nom", name: ""))

        XCTAssertEqual(
            model.selectedMedicineLabel(from: []),
            "m-sans-nom"
        )
        XCTAssertEqual(
            model.medicines(from: []).first?.name,
            "m-sans-nom"
        )
    }
}

// MARK: - Données de test indépendantes

private func historyEntry(
    id: String,
    medicineID: String,
    name: String
) -> HistoryEntry {
    let medicine = Medicine(
        id: medicineID,
        name: name,
        stock: 5,
        aisle: "A1",
        archived: false,
        version: 1
    )

    return HistoryEntry(
        id: id,
        medicineId: medicineID,
        userId: "test-user",
        userEmail: "test@example.com",
        action: "create",
        before: nil,
        after: medicine,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
