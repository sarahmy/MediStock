import Foundation
import Combine

// MARK: - Pagination commune

@MainActor
class PagedViewModel<Item: Identifiable>: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?

    private var cursor: PageCursor?
    private var generation = 0

    func load(
        reset: Bool,
        delay: Bool = false,
        fetch: (PageCursor?) async throws -> Page<Item>
    ) async {
        if !reset && (isLoading || !hasMore) {
            return
        }

        if reset {
            generation += 1
            cursor = nil
            items = []
            hasMore = true
        }

        let ticket = generation
        isLoading = true
        errorMessage = nil

        defer {
            if ticket == generation {
                isLoading = false
            }
        }

        do {
            if delay {
                try await Task.sleep(
                    nanoseconds: 300_000_000
                )
            }

            try Task.checkCancellation()

            let page = try await fetch(cursor)

            try Task.checkCancellation()

            guard ticket == generation else {
                return
            }

            let ids = Set(items.map(\.id))

            items += page.items.filter {
                !ids.contains($0.id)
            }

            cursor = page.cursor
            hasMore = page.hasMore

        } catch is CancellationError {
            // Une recherche annulée n'est pas une erreur utilisateur.

        } catch {
            if ticket == generation {
                errorMessage = userMessage(error)
            }
        }
    }
}

// MARK: - Liste des médicaments

@MainActor
final class MedicineStockViewModel: PagedViewModel<Medicine> {
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
        repository: InventoryRepository = FirestoreInventoryRepository()
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

// MARK: - Rayons

@MainActor
final class AislesViewModel: PagedViewModel<Aisle> {
    @Published private(set) var isSaving = false

    private let repository: InventoryRepository

    init(
        repository: InventoryRepository = FirestoreInventoryRepository()
    ) {
        self.repository = repository
        super.init()
    }

    // MARK: - Chargement

    func reload() async {
        guard !isSaving else {
            return
        }

        await refreshList()
    }

    func loadMore() async {
        guard !isSaving else {
            return
        }

        await load(reset: false) {
            try await self.repository.aisles(after: $0)
        }
    }

    private func refreshList() async {
        await load(reset: true) {
            try await self.repository.aisles(after: $0)
        }
    }

    // MARK: - Création et suppression

    func save(
        name: String,
        deleting: Bool = false
    ) async {
        await perform {
            if deleting {
                try await self.repository.deleteAisle(name)
            } else {
                try await self.repository.createAisle(name)
            }
        }
    }

    // MARK: - Renommage

    func rename(
        from oldName: String,
        to newName: String
    ) async {
        await perform {
            try await self.repository.renameAisle(
                from: oldName,
                to: newName
            )
        }
    }

    // MARK: - État commun des opérations

    private func perform(
        _ operation: () async throws -> Void
    ) async {
        guard !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            try await operation()
            await refreshList()

        } catch {
            let message = userMessage(error)

            // Actualise aussi après un échec, car un renommage
            // interrompu peut avoir déplacé certaines références.
            await refreshList()

            errorMessage = message
        }
    }
}

// MARK: - Détail d'un médicament

@MainActor
final class MedicineDetailViewModel: ObservableObject {
    @Published private(set) var medicine: Medicine?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    private let repository: InventoryRepository
    private let id: String

    private var generation = 0

    private var pending: (
        command: InventoryCommand,
        id: String
    )?

    init(
        id: String,
        repository: InventoryRepository = FirestoreInventoryRepository()
    ) {
        self.id = id
        self.repository = repository
    }

    func reload() async {
        generation += 1

        let ticket = generation
        isLoading = true

        defer {
            if ticket == generation {
                isLoading = false
            }
        }

        do {
            let value = try await repository.medicine(
                id: id
            )

            try Task.checkCancellation()

            guard ticket == generation else {
                return
            }

            medicine = value
            errorMessage = nil

        } catch is CancellationError {
            // La fermeture de l'écran peut annuler son chargement.

        } catch {
            if ticket == generation {
                errorMessage = userMessage(error)
            }
        }
    }

    func changeStock(_ delta: Int) async -> Bool {
        await execute(
            .stock(
                id: id,
                delta: delta
            )
        )
    }

    func archive() async -> Bool {
        await execute(
            .archive(id: id)
        )
    }

    private func execute(
        _ command: InventoryCommand
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        if pending?.command != command {
            pending = (
                command,
                UUID().uuidString
            )
        }

        guard let operationID = pending?.id else {
            return false
        }

        do {
            try await repository.apply(
                command,
                operationID: operationID
            )

            pending = nil

            await reload()

            return true

        } catch {
            errorMessage = userMessage(error)
            return false
        }
    }
}

// MARK: - Formulaire de création et de modification

@MainActor
final class MedicineFormViewModel: ObservableObject {
    @Published var name: String
    @Published var aisle: String
    @Published var stockText: String

    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    let original: Medicine?

    private let creationID = UUID().uuidString
    private let repository: InventoryRepository

    private var pending: (
        command: InventoryCommand,
        id: String
    )?

    init(
        medicine: Medicine? = nil,
        initialAisle: String = "",
        repository: InventoryRepository = FirestoreInventoryRepository()
    ) {
        original = medicine
        self.repository = repository

        name = medicine?.name ?? ""
        aisle = medicine?.aisle ?? initialAisle
        stockText = String(medicine?.stock ?? 0)
    }

    func save() async -> Bool {
        guard !isSaving else {
            return false
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            guard let stock = original?.stock ?? Int(stockText) else {
                throw StockError.invalidStock
            }

            let clean = try MedicineValidation.validate(
                name: name,
                stock: stock,
                aisle: aisle
            )

            let command: InventoryCommand

            if let original {
                command = .edit(
                    original,
                    name: clean.name,
                    aisle: clean.aisle
                )
            } else {
                command = .create(
                    Medicine(
                        id: creationID,
                        name: clean.name,
                        stock: stock,
                        aisle: clean.aisle
                    )
                )
            }

            if pending?.command != command {
                pending = (
                    command,
                    UUID().uuidString
                )
            }

            guard let operationID = pending?.id else {
                return false
            }

            try await repository.apply(
                command,
                operationID: operationID
            )

            pending = nil
            return true

        } catch {
            errorMessage = userMessage(error)
            return false
        }
    }
}
