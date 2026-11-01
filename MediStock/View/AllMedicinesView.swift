import SwiftUI

@MainActor
struct AllMedicinesView: View {
    var body: some View {
        NavigationStack {
            MedicineListView()
        }
    }
}
