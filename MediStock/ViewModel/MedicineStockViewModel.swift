
//
//  MedicineStockViewModel.swift
//  MediStock
//

import Foundation
import Combine

// MARK: - Liste des médicaments

@MainActor
final class MedicineStockViewModel:
    PagedViewModel<Medicine> {

    @Published var search = ""
    @Published var sort: MedicineSort = .name

    private let aisle: String?
    private let repository: InventoryRepository

    var filter: MedicineFilter {
        MedicineFilter(
            aisle: aisle,
            prefix: search,
            sort: sort
        )
    }

    init(
        aisle: String? = nil,
        repository: InventoryRepository =
            FirestoreInventoryRepository()
    ) {
        self.aisle = aisle
        self.repository = repository
        super.init()
    }

    func reload(debounce: Bool = false) async {
        let currentFilter = filter

        await load(
            reset: true,
            delay: debounce
        ) {
            try await self.repository.medicines(
                currentFilter,
                after: $0
            )
        }
    }

    func loadMore() async {
        let currentFilter = filter

        await load(reset: false) {
            try await self.repository.medicines(
                currentFilter,
                after: $0
            )
        }
    }
}
