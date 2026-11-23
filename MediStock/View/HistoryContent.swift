//
//  HistoryContent.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import SwiftUI

@MainActor
struct HistoryContent: View {

    @ObservedObject var viewModel: HistoryViewModel

    var cardStyle = false

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

            HStack(
                alignment: .top,
                spacing: 12
            ) {

                if cardStyle {
                    Image(
                        systemName: icon(for: entry.action)
                    )
                    .foregroundStyle(
                        MediStockTheme.primary
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        MediStockTheme.primary.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

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
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(
                .horizontal,
                cardStyle ? 14 : 0
            )
            .padding(
                .vertical,
                cardStyle ? 14 : 6
            )
            .background {
                if cardStyle {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    MediStockTheme.primary.opacity(0.09),
                                    lineWidth: 1
                                )
                        }
                }
            }
            .listRowBackground(
                cardStyle ? Color.clear : nil
            )
            .listRowSeparator(
                cardStyle ? .hidden : .automatic
            )
            .accessibilityElement(
                children: .combine
            )
        }

        if viewModel.isLoading {

            ProgressView(
                "Chargement de l'historique…"
            )

        } else if viewModel.items.isEmpty
                    && viewModel.errorMessage == nil {

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

    private func icon(for action: String) -> String {
        switch action {
        case "create":
            return "plus.square"

        case "edit":
            return "pencil"

        case "stock":
            return "shippingbox"

        case "archive":
            return "archivebox"

        default:
            return "clock.arrow.circlepath"
        }
    }
}

