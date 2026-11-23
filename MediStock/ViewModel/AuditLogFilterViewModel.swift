//
//  AuditLogFilterViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//

//  Etat des filtres et preparation des choix.
//  Aucun appel direct a Firestore.

import Foundation
import Combine

@MainActor
final class AuditLogFilterViewModel: ObservableObject {

    enum FilterMode {
        case date
        case medicine
    }

    struct MedicineChoice: Identifiable {
        let id: String
        let name: String
    }

    @Published private(set) var mode: FilterMode = .date
    @Published private(set) var sort: HistorySort = .newest
    @Published private(set) var selectedDay: Date?
    @Published private(set) var medicineID = ""
    @Published private(set) var selectedMedicineName = ""

    var historyFilter: HistoryFilter {
        switch mode {
        case .date:
            return HistoryFilter(
                day: selectedDay,
                sort: sort
            )

        case .medicine:
            return HistoryFilter(
                medicineID: medicineID.isEmpty
                    ? nil
                    : medicineID,
                sort: sort
            )
        }
    }

    func selectMode(_ value: FilterMode) {
        guard mode != value else { return }

        mode = value

        if value == .date {
            medicineID = ""
            selectedMedicineName = ""
        } else {
            selectedDay = nil
        }
    }

    func selectSort(_ value: HistorySort) {
        sort = value
    }

    func selectDay(_ value: Date?) {
        selectedDay = value.map {
            Calendar.current.startOfDay(for: $0)
        }
    }

    func selectMedicine(_ choice: MedicineChoice?) {
        medicineID = choice?.id ?? ""
        selectedMedicineName = choice?.name ?? ""
        selectedDay = nil
    }

    func medicines(
        from entries: [HistoryEntry]
    ) -> [MedicineChoice] {

        var ids = Set<String>()
        var result: [MedicineChoice] = []

        for entry in entries {
            guard ids.insert(entry.medicineId).inserted else {
                continue
            }

            result.append(
                MedicineChoice(
                    id: entry.medicineId,
                    name: entry.after.name
                )
            )
        }

        if !medicineID.isEmpty && !ids.contains(medicineID) {
            result.append(
                MedicineChoice(
                    id: medicineID,
                    name: selectedMedicineName.isEmpty
                        ? medicineID
                        : selectedMedicineName
                )
            )
        }

        return result.sorted {
            $0.name.localizedStandardCompare($1.name)
                == .orderedAscending
        }
    }

    func selectedMedicineLabel(
        from entries: [HistoryEntry]
    ) -> String {

        guard !medicineID.isEmpty else {
            return "Tous les médicaments"
        }

        return medicines(from: entries)
            .first(where: { $0.id == medicineID })?.name
            ?? (
                selectedMedicineName.isEmpty
                    ? medicineID
                    : selectedMedicineName
            )
    }
}
