//
//  PagedViewModel.swift
//  MediStock
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import Combine

// MARK: - Pagination commune

@MainActor
class PagedViewModel<Item: Identifiable>: ObservableObject {

    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?

    private var cursor: PageCursor?
    private var generation = 0

    func load(
        reset: Bool,
        delay: Bool = false,
        fetch: (PageCursor?) async throws -> Page<Item>
    ) async {

        if !reset && (isLoading || !hasMore) {
            return
        }

        if reset {
            generation += 1
            cursor = nil
            items = []
            hasMore = true
        }

        let ticket = generation
        isLoading = true
        errorMessage = nil

        defer {
            if ticket == generation {
                isLoading = false
            }
        }

        do {
            if delay {
                try await Task.sleep(
                    nanoseconds: 300_000_000
                )
            }

            try Task.checkCancellation()

            let page = try await fetch(cursor)

            try Task.checkCancellation()

            guard ticket == generation else {
                return
            }

            let ids = Set(items.map(\.id))

            items += page.items.filter {
                !ids.contains($0.id)
            }

            cursor = page.cursor
            hasMore = page.hasMore

        } catch is CancellationError {
            // Une recherche annulée n'est
            // pas une erreur utilisateur.
        } catch {
            if ticket == generation {
                errorMessage = userMessage(error)
            }
        }
    }
}
