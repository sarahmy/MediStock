//
//  AuditLogView.swift
//  MediStock
//
//  Created by Sarah Maimoun on 20/10/2026.
//


import SwiftUI

@MainActor
struct AuditLogView: View {

    @StateObject private var viewModel = HistoryViewModel()
    @StateObject private var choicesModel = HistoryViewModel()
    @StateObject private var filterModel = AuditLogFilterViewModel()

    @State private var dayToChoose = Date()
    @State private var showingDatePicker = false

    private var medicines: [AuditLogFilterViewModel.MedicineChoice] {
        filterModel.medicines(from: choicesModel.items)
    }

    // MARK: - Interface

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Filtres

                Section {
                    VStack(spacing: 14) {
                        HStack(spacing: 4) {
                            modeButton(
                                "Par date",
                                icon: "calendar",
                                value: .date
                            )

                            modeButton(
                                "Par médicament",
                                icon: "pills",
                                value: .medicine
                            )
                            .accessibilityIdentifier(
                                "Filtres et tri"
                            )
                        }
                        .padding(4)
                        .background(
                            MediStockTheme.primary.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 15)
                        )

                        if filterModel.mode == .date {
                            dateFilter
                        } else {
                            medicineFilter
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: 12,
                            leading: 16,
                            bottom: 8,
                            trailing: 16
                        )
                    )
                }

                // MARK: - Opérations

                Section {
                    HistoryContent(
                        viewModel: viewModel,
                        cardStyle: true
                    )
                } header: {
                    HStack(spacing: 8) {
                        Text("Opérations")

                        Spacer(minLength: 8)

                        Menu {
                            ForEach(HistorySort.allCases) { option in
                                Button {
                                    guard filterModel.sort != option else {
                                        return
                                    }

                                    filterModel.selectSort(option)
                                    applyFilter()

                                } label: {
                                    if filterModel.sort == option {
                                        Label(
                                            option.rawValue,
                                            systemImage: "checkmark"
                                        )
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(
                                    systemName: "arrow.up.arrow.down"
                                )

                                Text(filterModel.sort.rawValue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption)
                            .foregroundStyle(
                                MediStockTheme.primary
                            )
                        }
                        .accessibilityIdentifier(
                            "history.sortOrder"
                        )
                    }
                    .textCase(nil)
                }
            }
            .mediStockScreen()
            .navigationTitle("Historique")
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .task {
                await viewModel.reload()
            }
            .task {
                await choicesModel.reload()
            }
            .refreshable {
                await viewModel.reload()
                await choicesModel.reload()
            }
        }
    }

    // MARK: - Boutons de filtrage

    private func modeButton(
        _ title: String,
        icon: String,
        value: AuditLogFilterViewModel.FilterMode
    ) -> some View {

        let active = filterModel.mode == value

        return Button {
            guard filterModel.mode != value else {
                return
            }

            filterModel.selectMode(value)
            applyFilter()

        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .foregroundStyle(
                    active
                        ? Color.white
                        : MediStockTheme.primary
                )
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MediStockTheme.primary)
                    }
                }
                .contentShape(
                    RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            active ? [.isSelected] : []
        )
    }

    // MARK: - Filtre par date

    private var dateFilter: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                "Choisir une date",
                systemImage: "calendar"
            )
            .font(.subheadline.weight(.semibold))

            Button {
                dayToChoose = filterModel.selectedDay ?? Date()
                showingDatePicker = true

            } label: {
                HStack {
                    Text(
                        filterModel.selectedDay?.formatted(
                            date: .long,
                            time: .omitted
                        ) ?? "Choisir une date"
                    )

                    Spacer()

                    Image(systemName: "calendar")
                }
                .foregroundStyle(.primary)
                .padding(13)
                .background(
                    Color(
                        uiColor:
                            .secondarySystemGroupedBackground
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                "history.selectDate"
            )

            Button("Toutes les dates") {
                filterModel.selectDay(nil)
                applyFilter()
            }
            .font(.subheadline.weight(.medium))
            .disabled(filterModel.selectedDay == nil)
            .accessibilityIdentifier(
                "history.allDates"
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .background(
            MediStockTheme.primary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Filtre par médicament

    private var medicineFilter: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {
                Label(
                    "Médicament",
                    systemImage: "pills"
                )
                .font(.subheadline.weight(.semibold))

                Spacer()

                Text("A–Z")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        MediStockTheme.primary
                    )
            }

            Menu {
                Button("Tous les médicaments") {
                    selectMedicine(nil)
                }

                ForEach(medicines) { medicine in
                    Button(medicine.name) {
                        selectMedicine(medicine)
                    }
                }

                if choicesModel.hasMore
                    && !choicesModel.isLoading {

                    Divider()

                    Button("Charger d’autres médicaments") {
                        Task {
                            await choicesModel.loadMore()
                        }
                    }
                }

            } label: {
                HStack {
                    Text(
                        filterModel.selectedMedicineLabel(
                            from: choicesModel.items
                        )
                    )
                    .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                }
                .foregroundStyle(.primary)
                .padding(13)
                .background(
                    Color(
                        uiColor:
                            .secondarySystemGroupedBackground
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .accessibilityIdentifier(
                "history.selectMedicine"
            )

            if choicesModel.isLoading {
                ProgressView(
                    "Chargement des médicaments…"
                )
            }

            if let error = choicesModel.errorMessage {
                ErrorBanner(message: error)

                Button("Réessayer") {
                    Task {
                        await choicesModel.reload()
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .background(
            MediStockTheme.primary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Calendrier

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Choisir une date",
                selection: $dayToChoose,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Choisir une date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Annuler") {
                        showingDatePicker = false
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Afficher") {
                        filterModel.selectDay(dayToChoose)
                        showingDatePicker = false
                        applyFilter()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sélection du médicament

    private func selectMedicine(
        _ medicine: AuditLogFilterViewModel.MedicineChoice?
    ) {
        filterModel.selectMedicine(medicine)
        applyFilter()
    }

    // MARK: - Application du filtre et du tri

    private func applyFilter() {
        let filter = filterModel.historyFilter

        guard filter != viewModel.filter else {
            return
        }

        viewModel.filter = filter

        Task {
            await viewModel.reload()
        }
    }
}

