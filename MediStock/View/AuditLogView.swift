//
//  AuditLogView.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import SwiftUI

@MainActor
struct AuditLogView: View {

    private struct MedicineChoice: Identifiable {
        let id: String
        let name: String
    }

    @StateObject private var viewModel = HistoryViewModel()
    @StateObject private var choicesModel = HistoryViewModel()
    @StateObject private var authorsModel = HistoryAuthorsViewModel()

    @State private var userEmail = ""
    @State private var medicineID = ""
    @State private var selectedMedicineName = ""
    @State private var aisle = ""
    @State private var selectedDay: Date?

    @State private var sort: HistorySort = .newest
    @State private var filtersExpanded = false

    // MARK: - Utilisateurs

    private var users: [String] {
        let values = authorsModel.emails
            + (userEmail.isEmpty ? [] : [userEmail])

        return Array(Set(values)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    // MARK: - Médicaments

    private var medicines: [MedicineChoice] {
        var seen = Set<String>()
        var result: [MedicineChoice] = []

        for entry in choicesModel.items {
            if seen.insert(entry.medicineId).inserted {
                result.append(
                    MedicineChoice(
                        id: entry.medicineId,
                        name: entry.after.name
                    )
                )
            }
        }

        if !medicineID.isEmpty,
           !seen.contains(medicineID) {

            result.append(
                MedicineChoice(
                    id: medicineID,
                    name: selectedMedicineName.isEmpty
                        ? medicineID
                        : selectedMedicineName
                )
            )
        }

        return result.sorted {
            $0.name.localizedStandardCompare($1.name)
                == .orderedAscending
        }
    }

    // MARK: - Rayons

    private var aisles: [String] {
        let values = choicesModel.items.map(\.after.aisle)
            + (aisle.isEmpty ? [] : [aisle])

        return Array(Set(values)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    // MARK: - Jours

    private var days: [Date] {
        let loaded = choicesModel.items.map {
            Calendar.current.startOfDay(for: $0.timestamp)
        }

        let values = loaded
            + (selectedDay.map { [$0] } ?? [])

        return Array(Set(values)).sorted(by: >)
    }

    // MARK: - Interface

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DisclosureGroup(
                        "Filtres et tri",
                        isExpanded: $filtersExpanded
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: 14
                        ) {

                            // Tri des dates

                            Picker(
                                "Ordre chronologique",
                                selection: $sort
                            ) {
                                ForEach(
                                    HistorySort.allCases
                                ) { option in
                                    Text(option.rawValue)
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.menu)

                            // Filtre par utilisateur

                            Picker(
                                "Utilisateur",
                                selection: $userEmail
                            ) {
                                Text("Tous les utilisateurs")
                                    .tag("")

                                ForEach(
                                    users,
                                    id: \.self
                                ) { email in
                                    Text(email)
                                        .tag(email)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(
                                authorsModel.isLoading
                                || !authorsModel.hasLoaded
                            )

                            if authorsModel.isLoading {
                                ProgressView(
                                    "Recherche de tous les auteurs…"
                                )
                            }

                            if let error = authorsModel.errorMessage {
                                ErrorBanner(message: error)

                                Button(
                                    "Réessayer de charger les utilisateurs"
                                ) {
                                    Task {
                                        await authorsModel.reload()
                                    }
                                }
                            }

                            // Filtre par médicament

                            Picker(
                                "Médicament",
                                selection: $medicineID
                            ) {
                                Text("Tous les médicaments")
                                    .tag("")

                                ForEach(medicines) { medicine in
                                    Text(medicine.name)
                                        .tag(medicine.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: medicineID) { _, newID in
                                selectedMedicineName = medicines.first {
                                    $0.id == newID
                                }?.name ?? ""
                            }

                            // Filtre par rayon

                            Picker(
                                "Rayon",
                                selection: $aisle
                            ) {
                                Text("Tous les rayons")
                                    .tag("")

                                ForEach(
                                    aisles,
                                    id: \.self
                                ) { name in
                                    Text(name)
                                        .tag(name)
                                }
                            }
                            .pickerStyle(.menu)

                            // Filtre par jour

                            Picker(
                                "Jour",
                                selection: $selectedDay
                            ) {
                                Text("Tous les jours")
                                    .tag(Optional<Date>.none)

                                ForEach(
                                    days,
                                    id: \.self
                                ) { day in
                                    Text(
                                        day.formatted(
                                            date: .abbreviated,
                                            time: .omitted
                                        )
                                    )
                                    .tag(Optional(day))
                                }
                            }
                            .pickerStyle(.menu)

                            // Chargement des choix

                            if choicesModel.isLoading {
                                ProgressView("Chargement des choix…")
                            }

                            if let error = choicesModel.errorMessage {
                                ErrorBanner(message: error)

                                Button("Réessayer de charger les choix") {
                                    Task {
                                        await choicesModel.reload()
                                    }
                                }
                            }

                            if choicesModel.hasMore
                                && !choicesModel.isLoading {

                                Button("Charger d’autres choix") {
                                    Task {
                                        await choicesModel.loadMore()
                                    }
                                }
                            }

                            Text(
                                "Les auteurs sont recherchés dans tout "
                                + "l’historique. Les médicaments, rayons "
                                + "et jours sont proposés progressivement, "
                                + "par pages de 30 opérations. Les filtres "
                                + "s’appliquent ensuite dans Firestore."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                            // Appliquer

                            Button("Appliquer les filtres") {
                                applyFilters()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(
                                "history.applyFilters"
                            )

                            // Réinitialiser

                            Button("Réinitialiser les filtres") {
                                userEmail = ""
                                medicineID = ""
                                selectedMedicineName = ""
                                aisle = ""
                                selectedDay = nil
                                sort = .newest

                                applyFilters()
                            }
                            .accessibilityIdentifier(
                                "history.resetFilters"
                            )
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("Opérations") {
                    HistoryContent(viewModel: viewModel)
                }
            }
            .mediStockScreen()
            .navigationTitle("Historique")
            .onChange(of: filtersExpanded) { _, expanded in
                if expanded {
                    if !authorsModel.hasLoaded
                        && !authorsModel.isLoading {

                        Task {
                            await authorsModel.reload()
                        }
                    }

                    if choicesModel.items.isEmpty
                        && !choicesModel.isLoading {

                        Task {
                            await choicesModel.reload()
                        }
                    }
                }
            }
            .task {
                await viewModel.reload()
            }
            .refreshable {
                await viewModel.reload()

                if filtersExpanded {
                    await authorsModel.reload()
                    await choicesModel.reload()
                }
            }
        }
    }

    // MARK: - Requête filtrée

    private func applyFilters() {
        viewModel.filter = HistoryFilter(
            medicineID: medicineID.isEmpty
                ? nil
                : medicineID,
            userEmail: userEmail,
            aisle: aisle,
            day: selectedDay,
            sort: sort
        )

        Task {
            await viewModel.reload()
        }
    }
}

// MARK: - Affichage partagé de l'historique

@MainActor
struct HistoryContent: View {

    @ObservedObject var viewModel: HistoryViewModel

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {

        if let error = viewModel.errorMessage {
            ErrorBanner(message: error)

            Button("Réessayer") {
                Task {
                    await viewModel.reload()
                }
            }
        }

        ForEach(viewModel.items) { entry in
            VStack(alignment: .leading, spacing: 6) {

                Text(entry.title)
                    .font(.headline)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Text(entry.details)
                    .font(.body)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Label(
                    entry.userEmail,
                    systemImage: "person"
                )
                .font(.subheadline)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                Text(
                    entry.timestamp.formatted(
                        date: .abbreviated,
                        time: .standard
                    )
                )
                .font(.footnote)
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
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }

        if viewModel.isLoading {
            ProgressView("Chargement de l'historique…")

        } else if viewModel.items.isEmpty,
                  viewModel.errorMessage == nil {

            Text(
                viewModel.filter.medicineID != nil
                || !viewModel.filter.userEmail.isEmpty
                || !viewModel.filter.aisle.isEmpty
                || viewModel.filter.day != nil
                    ? "Aucune modification ne correspond aux filtres sélectionnés."
                    : "Aucune opération enregistrée."
            )
        }

        if viewModel.hasMore && !viewModel.isLoading {
            Button("Charger les opérations précédentes") {
                Task {
                    await viewModel.loadMore()
                }
            }
        }
    }
}
