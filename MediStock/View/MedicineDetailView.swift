//
//  MedicineDetailView.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import SwiftUI

@MainActor
struct MedicineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: MedicineDetailViewModel
    @StateObject private var history: HistoryViewModel

    @State private var showEdit = false
    @State private var confirmDelete = false

    init(medicineId: String) {
        _viewModel = StateObject(
            wrappedValue: MedicineDetailViewModel(id: medicineId)
        )

        _history = StateObject(
            wrappedValue: HistoryViewModel(medicineID: medicineId)
        )
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)

                Button("Actualiser") {
                    Task { await reload() }
                }
            }

            if viewModel.isLoading {
                ProgressView("Chargement…")
            }

            if let medicine = viewModel.medicine {
                Section {
                    Text(medicine.name)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Label(
                        medicine.aisle,
                        systemImage: "square.grid.2x2"
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }

                if medicine.archived {
                    Text(
                        "Médicament retiré du stock. Son historique est conservé."
                    )
                } else {
                    Section {
                        stockControls(medicine)

                        if viewModel.isSaving {
                            ProgressView("Enregistrement…")
                        }
                    } header: {
                        Text("Quantité en stock")
                            .foregroundStyle(
                                MediStockTheme.supportingText(for: colorScheme)
                            )
                    }
                }

                Section {
                    HistoryContent(viewModel: history)
                } header: {
                    Text("Historique des modifications")
                        .foregroundStyle(
                            MediStockTheme.supportingText(for: colorScheme)
                        )
                }

                if !medicine.archived {
                    Button(
                        "Supprimer du stock",
                        role: .destructive
                    ) {
                        confirmDelete = true
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .mediStockScreen()
        .navigationTitle("Fiche médicament")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let medicine = viewModel.medicine,
               !medicine.archived {
                Button("Modifier la fiche") {
                    showEdit = true
                }
                .disabled(viewModel.isSaving)
            }
        }
        .sheet(
            isPresented: $showEdit,
            onDismiss: {
                Task { await reload() }
            }
        ) {
            if let medicine = viewModel.medicine {
                MedicineFormView(medicine: medicine)
            }
        }
        .confirmationDialog(
            "Retirer ce médicament du stock ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(
                "Supprimer du stock",
                role: .destructive
            ) {
                Task {
                    if await viewModel.archive() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(
                "Il disparaîtra des listes actives, mais sa trace sera conservée."
            )
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func stockControls(
        _ medicine: Medicine
    ) -> some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        return layout {
            Button {
                change(-1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Retirer une unité")
            .disabled(
                viewModel.isSaving || medicine.stock <= 0
            )

            if !textSize.isAccessibilitySize {
                Spacer()
            }

            Text("\(medicine.stock)")
                .font(.title)
                .fontWeight(.semibold)
                .monospacedDigit()
                // Le stock ne doit jamais être tronqué : 1 000 000
                // est une valeur métier valide.
                .fixedSize(horizontal: true, vertical: true)
                .accessibilityLabel("Stock : \(medicine.stock) unités")

            if !textSize.isAccessibilitySize {
                Spacer()
            }

            Button {
                change(1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Ajouter une unité")
            .disabled(
                viewModel.isSaving || medicine.stock >= 1_000_000
            )
        }
    }

    private func change(_ delta: Int) {
        Task {
            if await viewModel.changeStock(delta) {
                await history.reload()
            }
        }
    }

    private func reload() async {
        await viewModel.reload()
        await history.reload()
    }
}
