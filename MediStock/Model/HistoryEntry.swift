import Foundation

struct HistoryEntry: Identifiable {
    let id: String
    let medicineId: String
    let userId: String
    let userEmail: String
    let action: String
    let before: Medicine?
    let after: Medicine
    let timestamp: Date

    var title: String {
        switch action {
        case "create":
            return "Création"
        case "edit":
            return "Modification"
        case "stock":
            return "Changement de stock"
        case "archive":
            return "Retrait du stock"
        default:
            return "Opération"
        }
    }

    var details: String {
        guard let before else {
            return "\(after.name) • rayon \(after.aisle) • stock \(after.stock)"
        }

        switch action {
        case "stock":
            return "\(after.name) : \(before.stock) → \(after.stock)"

        case "archive":
            return "\(before.name) retiré du rayon \(before.aisle), stock \(before.stock)."

        default:
            return "Nom : \(before.name) → \(after.name). Rayon : \(before.aisle) → \(after.aisle)."
        }
    }
}



enum HistorySort: String, CaseIterable, Identifiable {
    case newest = "Plus récentes d’abord"
    case oldest = "Plus anciennes d’abord"

    var id: String { rawValue }

    var descending: Bool {
        self == .newest
    }
}

struct HistoryFilter: Equatable {
    var medicineID: String? = nil
    var userEmail = ""
    var medicineName = ""
    var aisle = ""
    var day: Date? = nil
    var sort: HistorySort = .newest

    var usesAdvancedFilters: Bool {
        !userEmail.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        || !medicineName.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        || !aisle.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        || day != nil
        || sort != .newest
    }
}
