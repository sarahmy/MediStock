import SwiftUI

@MainActor
struct AisleListView: View {
    @StateObject private var viewModel = AislesViewModel()

    @State private var showEditor = false
    @State private var editedAisle: Aisle?
    @State private var name = ""

    @State private var deletedAisle: Aisle?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)

                        Button("Actualiser") {
                            Task {
                                await viewModel.reload()
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }

                ForEach(viewModel.items) { aisle in
                    HStack(spacing: 12) {
                        NavigationLink {
                            MedicineListView(aisle: aisle.id)
                        } label: {
                            HStack(spacing: 14) {
                                Image(
                                    systemName: "square.grid.2x2"
                                )
                                .font(.title3)
                                .foregroundStyle(
                                    MediStockTheme.primary
                                )
                                .frame(
                                    minWidth: 44,
                                    minHeight: 44
                                )
                                .background(
                                    MediStockTheme.primary
                                        .opacity(0.10)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 12
                                    )
                                )

                                Text(aisle.id)
                                    .font(.headline)
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                            }
                            .padding(.vertical, 5)
                        }
                        .disabled(viewModel.isSaving)

                        Menu {
                            Button {
                                editedAisle = aisle
                                name = aisle.id
                                showEditor = true
                            } label: {
                                Label(
                                    "Renommer",
                                    systemImage: "pencil"
                                )
                            }

                            Button(role: .destructive) {
                                deletedAisle = aisle
                                confirmDelete = true
                            } label: {
                                Label(
                                    "Supprimer",
                                    systemImage: "trash"
                                )
                            }

                        } label: {
                            Image(
                                systemName: "ellipsis.circle"
                            )
                            .font(.title3)
                            .frame(
                                minWidth: 44,
                                minHeight: 44
                            )
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            "Actions du rayon \(aisle.id)"
                        )
                        .disabled(viewModel.isSaving)
                    }
                }

                if viewModel.isSaving {
                    ProgressView("Enregistrement…")

                } else if viewModel.isLoading {
                    ProgressView("Chargement…")

                } else if viewModel.items.isEmpty,
                          viewModel.errorMessage == nil {
                    Text("Aucun rayon")
                        .foregroundStyle(.secondary)
                }

                if viewModel.hasMore
                    && !viewModel.isLoading
                    && !viewModel.isSaving {
                    Button("Charger les suivants") {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .mediStockScreen()
            .navigationTitle("Rayons")
            .toolbar {
                Button {
                    editedAisle = nil
                    name = ""
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Créer un rayon")
                .disabled(viewModel.isSaving)
            }
            .alert(
                editedAisle == nil
                    ? "Créer un rayon"
                    : "Renommer le rayon",
                isPresented: $showEditor
            ) {
                TextField(
                    "Nom du rayon",
                    text: $name
                )
                .autocorrectionDisabled()

                Button("Enregistrer") {
                    let source = editedAisle
                    let enteredName = name

                    Task {
                        if let source {
                            await viewModel.rename(
                                from: source.id,
                                to: enteredName
                            )
                        } else {
                            await viewModel.save(
                                name: enteredName
                            )
                        }
                    }
                }

                Button(
                    "Annuler",
                    role: .cancel
                ) {}

            } message: {
                if editedAisle != nil {
                    Text(
                        "Les références conserveront leur quantité "
                        + "et leur historique."
                    )
                }
            }
            .confirmationDialog(
                "Supprimer le rayon "
                    + "« \(deletedAisle?.id ?? "") » ?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button(
                    "Supprimer",
                    role: .destructive
                ) {
                    guard let aisle = deletedAisle else {
                        return
                    }

                    Task {
                        await viewModel.save(
                            name: aisle.id,
                            deleting: true
                        )
                    }
                }

                Button(
                    "Annuler",
                    role: .cancel
                ) {}

            } message: {
                Text(
                    "Le rayon doit être vide. "
                    + "Aucun médicament ne sera supprimé."
                )
            }
            .task {
                await viewModel.reload()
            }
            .refreshable {
                await viewModel.reload()
            }
        }
    }
}
