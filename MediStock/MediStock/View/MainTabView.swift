import SwiftUI

@MainActor
struct MainTabView: View {
    var body: some View {
        TabView {
            AisleListView()
                .tabItem {
                    Label(
                        "Rayons",
                        systemImage: "square.grid.2x2"
                    )
                }

            AllMedicinesView()
                .tabItem {
                    Label(
                        "Stock",
                        systemImage: "shippingbox"
                    )
                }

            AuditLogView()
                .tabItem {
                    Label(
                        "Historique",
                        systemImage: "clock.arrow.circlepath"
                    )
                }

            AccountView()
                .tabItem {
                    Label(
                        "Compte",
                        systemImage: "person.crop.circle"
                    )
                }
        }
    }
}
