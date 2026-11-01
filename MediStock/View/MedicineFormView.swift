//
//  MedicineFormView.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//

import SwiftUI

@MainActor
struct MedicineFormView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: MedicineFormViewModel
    @StateObject private var aislesViewModel = AislesViewModel()

    private let isAisleLocked: Bool

    init(
        medicine: Medicine? = nil,
        initialAisle: String = ""
    ) {
        // Lors d'un ajout depuis un rayon,
        // on conserve le rayon depuis lequel l'utilisateur vient.
        isAisleLocked =
            medicine == nil && !initialAisle.isEmpty

        _viewModel = StateObject(
            wrappedValue: MedicineFormViewModel(
                medicine: medicine,
                initialAisle: initialAisle
            )
        )
    }

    private var selectionIsOutsideLoadedPage: Bool {
        !viewModel.aisle.isEmpty
            && !aislesViewModel.items.contains {
                $0.id == viewModel.aisle
            }
    }

    private var cannotSave: Bool {
        viewModel.isSaving
            || viewModel.aisle.isEmpty
            || (
                !isAisleLocked
                && aislesViewModel.isLoading
            )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Référence") {
                    TextField(
                        "Nom de la référence",
                        text: $viewModel.name
                    )

                    if viewModel.original == nil {
                        LabeledContent("Stock initial") {
                            TextField(
                                "0",
                                text: $viewModel.stockText
                            )
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Stock initial")
                        }
                    }
                }

                Section("Rayon") {
                    aisleSelection
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                    }
                }

                if viewModel.isSaving {
                    ProgressView("Enregistrement…")
                }
            }
            .disabled(viewModel.isSaving)
            .mediStockScreen()
            .navigationTitle(
                viewModel.original == nil
                ? "Nouvelle référence"
                : "Modifier la fiche"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(cannotSave)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .task {
                // Pas de chargement inutile si le rayon est fixé.
                if !isAisleLocked {
                    await aislesViewModel.reload()
                }
            }
        }
    }

    @ViewBuilder
    private var aisleSelection: some View {
        if isAisleLocked {
            LabeledContent(
                "Rayon sélectionné",
                value: viewModel.aisle
            )

        } else {
            Picker(
                "Rayon",
                selection: $viewModel.aisle
            ) {
                Text("Choisir un rayon")
                    .tag("")

                // Conserve la sélection actuelle pendant le chargement,
                // ou si elle ne figure pas dans la première page.
                if selectionIsOutsideLoadedPage {
                    Text(viewModel.aisle)
                        .tag(viewModel.aisle)
                }

                ForEach(aislesViewModel.items) { aisle in
                    Text(aisle.id)
                        .tag(aisle.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(
                aislesViewModel.isLoading
                || (
                    aislesViewModel.items.isEmpty
                    && viewModel.aisle.isEmpty
                )
            )
            .accessibilityIdentifier("medicine.aisle")

            if aislesViewModel.isLoading {
                ProgressView("Chargement des rayons…")
            }

            if let error = aislesViewModel.errorMessage {
                ErrorBanner(message: error)

                Button("Réessayer") {
                    Task {
                        await aislesViewModel.reload()
                    }
                }
                .disabled(aislesViewModel.isLoading)
            }

            if !aislesViewModel.isLoading,
               aislesViewModel.errorMessage == nil {

                if aislesViewModel.items.isEmpty {
                    Text(
                        "Aucun rayon disponible. Crée d'abord un rayon dans l'onglet Rayons."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if aislesViewModel.hasMore {
                    Button("Charger d’autres rayons") {
                        Task {
                            await aislesViewModel.loadMore()
                        }
                    }
                }
            }
        }
    }
}
