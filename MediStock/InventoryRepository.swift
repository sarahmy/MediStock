//
//  InventoryRepository.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

struct PageCursor {
    fileprivate let document: DocumentSnapshot
}

struct Page<Item> {
    let items: [Item]
    let cursor: PageCursor?
    let hasMore: Bool
}

protocol InventoryRepository {
    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine>

    func medicine(id: String) async throws -> Medicine

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry>

    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry>

    func aisles(after: PageCursor?) async throws -> Page<Aisle>

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws

    func createAisle(_ name: String) async throws
    func deleteAisle(_ name: String) async throws
}


extension InventoryRepository {
    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        guard !filter.usesAdvancedFilters else {
            throw StockError.message(
                "Les filtres avancés ne sont pas disponibles avec ce dépôt."
            )
        }

        return try await history(
            medicineID: filter.medicineID,
            after: after
        )
    }
}

actor FirestoreInventoryRepository: InventoryRepository {
    private let sessionUID = Auth.auth().currentUser?.uid

    private var db: Firestore {
        Firestore.firestore()
    }

    private let pageSize = 30

    private func identity() throws -> (
        uid: String,
        email: String
    ) {
        guard
            let user = Auth.auth().currentUser,
            user.uid == sessionUID,
            let email = user.email,
            !email.isEmpty
        else {
            throw StockError.disconnected
        }

        return (user.uid, email)
    }

    private func page<T>(
        _ query: Query,
        after: PageCursor?,
        decode: (QueryDocumentSnapshot) throws -> T
    ) async throws -> Page<T> {
        _ = try identity()

        var query = query.limit(to: pageSize)

        if let after {
            query = query.start(
                afterDocument: after.document
            )
        }

        let result = try await query.getDocuments(
            source: .server
        )

        try Task.checkCancellation()
        _ = try identity()

        return Page(
            items: try result.documents.map(decode),
            cursor: result.documents.last.map {
                PageCursor(document: $0)
            },
            hasMore: result.documents.count == pageSize
        )
    }

    // MARK: - Liste et tri des médicaments

    func medicines(
        _ filter: MedicineFilter,
        after: PageCursor?
    ) async throws -> Page<Medicine> {
        var query: Query = db.collection("medicines")
            .whereField(
                "archived",
                isEqualTo: false
            )

        if let aisle = filter.aisle {
            query = query.whereField(
                "aisle",
                isEqualTo: aisle
            )
        }

        let prefix = filter.prefix
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if prefix.isEmpty {
            switch filter.sort {
            case .name:
                query = query.order(
                    by: "nameKey"
                )

            case .stock:
                query = query.order(
                    by: "stock"
                )

            case .stockDescending:
                query = query.order(
                    by: "stock",
                    descending: true
                )
            }
        } else {
            query = query.whereField(
                "nameKey",
                isGreaterThanOrEqualTo: prefix
            )

            if let upper = Self.upperBound(prefix) {
                query = query.whereField(
                    "nameKey",
                    isLessThan: upper
                )
            }

            query = query.order(by: "nameKey")
        }

        query = query.order(
            by: FieldPath.documentID(),
            descending: prefix.isEmpty && filter.sort == .stockDescending
        )

        return try await page(
            query,
            after: after
        ) {
            try Self.decode($0)
        }
    }

    func medicine(id: String) async throws -> Medicine {
        _ = try identity()

        let document = try await db
            .collection("medicines")
            .document(id)
            .getDocument(source: .server)

        try Task.checkCancellation()
        _ = try identity()

        return try Self.decode(document)
    }

    // MARK: - Historique et filtres

    func history(
        medicineID: String?,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        try await history(
            HistoryFilter(medicineID: medicineID),
            after: after
        )
    }

    func history(
        _ filter: HistoryFilter,
        after: PageCursor?
    ) async throws -> Page<HistoryEntry> {
        var query: Query = db.collection("history")

        if let medicineID = filter.medicineID {
            query = query.whereField(
                "medicineId",
                isEqualTo: medicineID
            )
        }

        let email = filter.userEmail
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !email.isEmpty {
            query = query.whereField(
                "userEmail",
                isEqualTo: email
            )
        }

        let name = filter.medicineName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !name.isEmpty {
            // Nom exact au moment de la modification,
            // sensible à la casse.
            query = query.whereField(
                "after.name",
                isEqualTo: name
            )
        }

        let aisle = filter.aisle
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !aisle.isEmpty {
            // Rayon APRÈS l'opération,
            // y compris lors d'un déplacement.
            query = query.whereField(
                "after.aisle",
                isEqualTo: aisle
            )
        }

        if let selectedDay = filter.day {
            guard let interval = Calendar.current
                .dateInterval(
                    of: .day,
                    for: selectedDay
                )
            else {
                throw StockError.message(
                    "Date de filtre invalide."
                )
            }

            query = query
                .whereField(
                    "timestamp",
                    isGreaterThanOrEqualTo: interval.start
                )
                .whereField(
                    "timestamp",
                    isLessThan: interval.end
                )
        }

        query = query
            .order(
                by: "timestamp",
                descending: filter.sort.descending
            )
            .order(
                by: FieldPath.documentID(),
                descending: filter.sort.descending
            )

        return try await page(
            query,
            after: after
        ) { document in
            let data = document.data()

            guard
                let id = data["medicineId"] as? String,
                let uid = data["userId"] as? String,
                let email = data["userEmail"] as? String,
                let action = data["action"] as? String,
                let timestamp = data["timestamp"] as? Timestamp,
                let next = data["after"] as? [String: Any]
            else {
                throw StockError.corrupted
            }

            let previous = try (
                data["before"] as? [String: Any]
            ).map {
                try Self.decodeState(
                    $0,
                    id: id
                )
            }

            return HistoryEntry(
                id: document.documentID,
                medicineId: id,
                userId: uid,
                userEmail: email,
                action: action,
                before: previous,
                after: try Self.decodeState(
                    next,
                    id: id
                ),
                timestamp: timestamp.dateValue()
            )
        }
    }

    // MARK: - Rayons

    func aisles(
        after: PageCursor?
    ) async throws -> Page<Aisle> {
        try await page(
            db.collection("aisles").order(
                by: FieldPath.documentID()
            ),
            after: after
        ) {
            guard let count = $0.data()["count"] as? Int else {
                throw StockError.corrupted
            }

            return Aisle(
                id: $0.documentID,
                count: count
            )
        }
    }

    func createAisle(_ name: String) async throws {
        let uid = try identity().uid
        let name = try MedicineValidation.aisle(name)
        let reference = db.collection("aisles")
            .document(name)

        _ = try await db.runTransaction {
            transaction, pointer -> Any? in

            do {
                guard Auth.auth().currentUser?.uid == uid else {
                    throw StockError.disconnected
                }

                guard !(
                    try transaction
                        .getDocument(reference)
                ).exists else {
                    throw StockError.message(
                        "Ce rayon existe déjà."
                    )
                }

                transaction.setData(
                    [
                        "count": 0,
                        "eventID": ""
                    ],
                    forDocument: reference
                )

                return true
            } catch {
                pointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func deleteAisle(_ name: String) async throws {
        let uid = try identity().uid
        let reference = db.collection("aisles")
            .document(name)

        _ = try await db.runTransaction {
            transaction, pointer -> Any? in

            do {
                guard Auth.auth().currentUser?.uid == uid else {
                    throw StockError.disconnected
                }

                let document = try transaction
                    .getDocument(reference)

                guard document.data()?["count"] as? Int == 0 else {
                    throw StockError.message(
                        "Le rayon doit être vide avant suppression."
                    )
                }

                transaction.deleteDocument(reference)

                return true
            } catch {
                pointer?.pointee = error as NSError
                return nil
            }
        }
    }

    // MARK: - Transactions du stock et de l'historique

    func apply(
        _ command: InventoryCommand,
        operationID: String
    ) async throws {
        let person = try identity()
        let database = db

        let reference = database.collection("medicines")
            .document(command.medicineID)

        let eventReference = database.collection("history")
            .document(operationID)

        _ = try await database.runTransaction {
            transaction, pointer -> Any? in

            do {
                guard
                    Auth.auth().currentUser?.uid == person.uid
                else {
                    throw StockError.disconnected
                }

                let event = try transaction
                    .getDocument(eventReference)

                if event.exists {
                    guard
                        event.data()?["userId"] as? String
                            == person.uid,
                        event.data()?["medicineId"] as? String
                            == command.medicineID
                    else {
                        throw StockError.conflict
                    }

                    // La même opération a déjà été enregistrée.
                    return true
                }

                let document = try transaction
                    .getDocument(reference)

                let old = document.exists
                    ? try Self.decode(document)
                    : nil

                var next: Medicine
                let action: String

                switch command {
                case .create(let draft):
                    guard old == nil else {
                        throw StockError.conflict
                    }

                    next = draft
                    next.archived = false
                    next.version = 1
                    action = "create"

                case .edit(
                    let expected,
                    let name,
                    let aisle
                ):
                    guard let previous = old,
                          !previous.archived
                    else {
                        throw StockError.missing
                    }

                    guard
                        previous.version == expected.version
                    else {
                        throw StockError.conflict
                    }

                    next = previous
                    next.name = name
                    next.aisle = aisle
                    next.version += 1
                    action = "edit"

                case .stock(_, let delta):
                    guard let previous = old,
                          !previous.archived
                    else {
                        throw StockError.missing
                    }

                    next = previous
                    next.stock = try MedicineValidation
                        .adjustedStock(
                            current: previous.stock,
                            delta: delta
                        )
                    next.version += 1
                    action = "stock"

                case .archive:
                    guard let previous = old,
                          !previous.archived
                    else {
                        throw StockError.missing
                    }

                    next = previous
                    next.archived = true
                    next.version += 1
                    action = "archive"
                }

                let clean = try MedicineValidation.validate(
                    name: next.name,
                    stock: next.stock,
                    aisle: next.aisle
                )

                next.name = clean.name
                next.aisle = clean.aisle

                if let old,
                   old.name == next.name,
                   old.stock == next.stock,
                   old.aisle == next.aisle,
                   old.archived == next.archived {
                    return true
                }

                // Compteurs internes pour protéger
                // les rayons occupés.
                let previousAisle = old.flatMap {
                    $0.archived ? nil : $0.aisle
                }

                let nextAisle: String? = next.archived
                    ? nil
                    : next.aisle

                var counters: [
                    (DocumentReference, Int)
                ] = []

                if previousAisle != nextAisle {
                    let names = Set(
                        [
                            previousAisle,
                            nextAisle
                        ].compactMap { $0 }
                    )

                    for name in names {
                        let aisleRef = database
                            .collection("aisles")
                            .document(name)

                        let snapshot = try transaction
                            .getDocument(aisleRef)

                        guard let count = snapshot
                            .data()?["count"] as? Int
                        else {
                            throw StockError.message(
                                "Crée d'abord le rayon \(name)."
                            )
                        }

                        let value = count
                            + (nextAisle == name ? 1 : 0)
                            - (previousAisle == name ? 1 : 0)

                        guard value >= 0 else {
                            throw StockError.corrupted
                        }

                        counters.append(
                            (aisleRef, value)
                        )
                    }
                }

                // Toutes les lectures précèdent
                // les écritures.
                var data = Self.state(next)
                data["nameKey"] = next.name.lowercased()
                data["eventID"] = operationID
                data["updatedAt"] =
                    FieldValue.serverTimestamp()

                transaction.setData(
                    data,
                    forDocument: reference
                )

                transaction.setData(
                    [
                        "medicineId": next.id,
                        "userId": person.uid,
                        "userEmail": person.email,
                        "action": action,
                        "before": old.map {
                            Self.state($0) as Any
                        } ?? NSNull(),
                        "after": Self.state(next),
                        "timestamp":
                            FieldValue.serverTimestamp()
                    ],
                    forDocument: eventReference
                )

                for (aisleRef, count) in counters {
                    transaction.updateData(
                        [
                            "count": count,
                            "eventID": operationID
                        ],
                        forDocument: aisleRef
                    )
                }

                return true
            } catch {
                pointer?.pointee = error as NSError
                return nil
            }
        }
    }

    // MARK: - Conversion des données

    private static func state(
        _ medicine: Medicine
    ) -> [String: Any] {
        [
            "name": medicine.name,
            "stock": medicine.stock,
            "aisle": medicine.aisle,
            "archived": medicine.archived,
            "version": medicine.version
        ]
    }

    private static func decode(
        _ document: DocumentSnapshot
    ) throws -> Medicine {
        guard let data = document.data() else {
            throw StockError.missing
        }

        return try decodeState(
            data,
            id: document.documentID
        )
    }

    private static func decodeState(
        _ data: [String: Any],
        id: String
    ) throws -> Medicine {
        guard
            let name = data["name"] as? String,
            let stock = data["stock"] as? Int,
            let aisle = data["aisle"] as? String,
            let archived = data["archived"] as? Bool,
            let version = data["version"] as? Int
        else {
            throw StockError.corrupted
        }

        return Medicine(
            id: id,
            name: name,
            stock: stock,
            aisle: aisle,
            archived: archived,
            version: version
        )
    }

    private static func upperBound(
        _ prefix: String
    ) -> String? {
        var scalars = Array(prefix.unicodeScalars)

        while let last = scalars.popLast() {
            var value = last.value + 1

            if value == 0xD800 {
                value = 0xE000
            }

            if let next = UnicodeScalar(value) {
                scalars.append(next)

                return String(
                    String.UnicodeScalarView(scalars)
                )
            }
        }

        return nil
    }
}

// MARK: - Renommage des rayons

extension InventoryRepository {
    func renameAisle(
        from oldName: String,
        to input: String
    ) async throws {
        let newName = try MedicineValidation.aisle(input)

        guard newName != oldName else {
            return
        }

        let filter = MedicineFilter(
            aisle: oldName
        )

        var page = try await medicines(
            filter,
            after: nil
        )

        // Refuse un nom déjà utilisé.
        try await createAisle(newName)

        do {
            while true {
                try Task.checkCancellation()

                for medicine in page.items {
                    try Task.checkCancellation()

                    try await apply(
                        .edit(
                            medicine,
                            name: medicine.name,
                            aisle: newName
                        ),
                        operationID: UUID().uuidString
                    )
                }

                guard page.hasMore else {
                    break
                }

                guard let cursor = page.cursor else {
                    throw StockError.corrupted
                }

                page = try await medicines(
                    filter,
                    after: cursor
                )
            }

            try await deleteAisle(oldName)

        } catch {
            throw StockError.message(
                "Renommage interrompu. Certaines références peuvent "
                + "déjà être dans « \(newName) ». "
                + "Vérifie les deux rayons avant de poursuivre. "
                + userMessage(error)
            )
        }
    }
}
