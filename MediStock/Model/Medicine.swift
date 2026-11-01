import Foundation

struct Medicine: Identifiable, Equatable {
    let id: String
    var name: String
    var stock: Int
    var aisle: String
    var archived = false
    var version = 0
}

struct Aisle: Identifiable, Equatable {
    let id: String
    let count: Int
}

enum MedicineSort: String, CaseIterable, Identifiable {
    case name = "Nom"
    case stock = "Stock"
    case stockDescending = "Stock décroissant"

    var id: String { rawValue }
}

struct MedicineFilter: Equatable {
    var aisle: String? = nil
    var prefix = ""
    var sort: MedicineSort = .name
}

enum InventoryCommand: Equatable {
    case create(Medicine)
    case edit(Medicine, name: String, aisle: String)
    case stock(id: String, delta: Int)
    case archive(id: String)

    var medicineID: String {
        switch self {
        case .create(let medicine), .edit(let medicine, _, _):
            return medicine.id

        case .stock(let id, _), .archive(let id):
            return id
        }
    }
}

enum StockError: LocalizedError {
    case invalidName
    case invalidAisle
    case invalidStock
    case missing
    case conflict
    case disconnected
    case corrupted
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Saisis un nom de 1 à 80 caractères sur une seule ligne."

        case .invalidAisle:
            return "Saisis un rayon de 1 à 60 caractères, sans /, distinct de . et .. ."

        case .invalidStock:
            return "Le stock doit être un entier entre 0 et 1 000 000."

        case .missing:
            return "Ce médicament n'existe plus dans le stock actif."

        case .conflict:
            return "La fiche a changé. Ferme le formulaire, actualise et recommence."

        case .disconnected:
            return "La session a changé. Reconnecte-toi avant de recommencer."

        case .corrupted:
            return "Une donnée n'utilise pas le format attendu."

        case .message(let message):
            return message
        }
    }
}

enum MedicineValidation {
    static func aisle(_ input: String) throws -> String {
        let value = input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !value.isEmpty,
            value.count <= 60,
            !value.contains("/"),
            value != ".",
            value != "..",
            !(value.hasPrefix("__") && value.hasSuffix("__")),
            value.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            throw StockError.invalidAisle
        }

        return value
    }

    static func validate(
        name: String,
        stock: Int,
        aisle: String
    ) throws -> (name: String, aisle: String) {
        let name = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !name.isEmpty,
            name.count <= 80,
            name.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            throw StockError.invalidName
        }

        guard (0...1_000_000).contains(stock) else {
            throw StockError.invalidStock
        }

        return (name, try Self.aisle(aisle))
    }

    static func adjustedStock(
        current: Int,
        delta: Int
    ) throws -> Int {
        let (result, overflow) = current.addingReportingOverflow(delta)

        guard !overflow, (0...1_000_000).contains(result) else {
            throw StockError.invalidStock
        }

        return result
    }
}

// Messages affichés dans l'application.
// Les informations techniques restent uniquement dans Xcode en Debug.

func userMessage(_ error: Error) -> String {
    if let stockError = error as? StockError {
        return stockError.localizedDescription
    }

    let detail = error as NSError

    if detail.domain == "FIRFirestoreErrorDomain" {
        switch detail.code {
        case 7:
            return "Tu n'as pas accès à ces informations. Reconnecte-toi ou contacte le responsable."

        case 9:
            #if DEBUG
            print(
                "[MediStock] Diagnostic requête : \(detail.localizedDescription)"
            )
            #endif

            return "Impossible d'afficher les résultats pour le moment. Réessaie un peu plus tard."

        case 14:
            return "Connexion indisponible. Vérifie le réseau, puis réessaie."

        default:
            break
        }
    }

    #if DEBUG
    print("[MediStock] Erreur technique : \(detail)")
    #endif

    return "Impossible de terminer l'opération. Réessaie dans un instant."
}
