import SwiftUI

@MainActor
struct MedicineListView: View {
    private let aisle: String?

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.colorScheme)
    private var colorScheme

    @StateObject private var viewModel: MedicineStockViewModel
    @State private var showAdd = false

    init(aisle: String? = nil) {
        self.aisle = aisle

        _viewModel = StateObject(
            wrappedValue: MedicineStockViewModel(
                aisle: aisle
            )
        )
    }

    private var isSearching: Bool {
        !viewModel.search.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    var body: some View {
        List {
            if let aisle {
                Section {
                    Text(aisle)
                        .font(.title3.bold())
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .accessibilityAddTraits(.isHeader)
                }
            }

            Section {
                if isSearching {
                    LabeledContent(
                        "Trier par",
                        value: "Nom A–Z"
                    )
                } else {
                    Picker(
                        "Trier par",
                        selection: $viewModel.sort
                    ) {
                        Text("Nom A–Z")
                            .tag(MedicineSort.name)

                        Text("Stock croissant")
                            .tag(MedicineSort.stock)

                        Text("Stock décroissant")
                            .tag(MedicineSort.stockDescending)
                    }
                    .pickerStyle(.menu)
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: error)

                    Button("Réessayer") {
                        Task {
                            await viewModel.reload()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            ForEach(viewModel.items) { medicine in
                NavigationLink {
                    MedicineDetailView(
                        medicineId: medicine.id
                    )
                } label: {
                    medicineRow(medicine)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .accessibilityElement(
                            children: .combine
                        )
                }
                .accessibilityHint(
                    "Ouvre la fiche et son historique"
                )
            }

            if viewModel.isLoading {
                ProgressView("Chargement…")

            } else if viewModel.items.isEmpty,
                      viewModel.errorMessage == nil {

                Text(
                    isSearching
                        ? "Aucune référence trouvée."
                        : "Aucune référence dans cette liste."
                )
                .foregroundStyle(.secondary)
            }

            if viewModel.hasMore && !viewModel.isLoading {
                Button("Charger les suivants") {
                    Task {
                        await viewModel.loadMore()
                    }
                }
            }
        }
        .mediStockScreen()
        .navigationTitle(
            aisle == nil ? "Stock" : "Rayon"
        )
        .navigationBarTitleDisplayMode(
            aisle == nil ? .large : .inline
        )
        .searchable(
            text: $viewModel.search,
            prompt: "Début du nom d’une référence"
        )
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(
                    "Ajouter une référence"
                )
            }
        }
        .sheet(
            isPresented: $showAdd,
            onDismiss: {
                Task {
                    await viewModel.reload()
                }
            }
        ) {
            MedicineFormView(
                initialAisle: aisle ?? ""
            )
        }
        .task(id: viewModel.filter) {
            await viewModel.reload(
                debounce: true
            )
        }
        .refreshable {
            await viewModel.reload()
        }
    }

    private func medicineRow(
        _ medicine: Medicine
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            Image(systemName: "pills")
                .font(.body)
                .foregroundStyle(
                    MediStockTheme.primary
                )
                .accessibilityHidden(true)
                .padding(.top, 2)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    medicineIdentity(medicine)

                    medicineQuantity(
                        medicine,
                        alignment: .leading
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            } else {
                HStack(
                    alignment: .center,
                    spacing: 12
                ) {
                    medicineIdentity(medicine)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    medicineQuantity(
                        medicine,
                        alignment: .trailing
                    )
                }
            }
        }
    }

    private func medicineIdentity(
        _ medicine: Medicine
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(medicine.name)
                .font(.headline)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if aisle == nil {
                Text(medicine.aisle)
                    .font(.subheadline)
                    .foregroundStyle(
                        MediStockTheme.supportingText(
                            for: colorScheme
                        )
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
    }

    private func medicineQuantity(
        _ medicine: Medicine,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(
            alignment: alignment,
            spacing: 4
        ) {
            Text("\(medicine.stock)")
                .font(.headline)
                .monospacedDigit()
                .fixedSize(
                    horizontal: true,
                    vertical: true
                )

            Text("en stock")
                .font(.subheadline)
                .foregroundStyle(
                    MediStockTheme.supportingText(
                        for: colorScheme
                    )
                )
        }
    }
}
