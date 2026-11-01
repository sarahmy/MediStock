import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if session.isChecking {
                VStack(spacing: 24) {
                    MediStockLogo()
                    ProgressView("Ouverture de la session…")
                }

            } else if let user = session.user {
                if session.accessStatus == .allowed {
                    MainTabView()
                        .id(user.uid)
                } else {
                    StockAccessScreen()
                }

            } else {
                LoginView()
            }
        }
        .tint(MediStockTheme.primary)
        .task {
            session.startListening()
        }
        .overlay {
            if phase != .active {
                ZStack {
                    Rectangle()
                        .fill(.background)
                        .ignoresSafeArea()

                    MediStockLogo()
                }
                .accessibilityHidden(true)
            }
        }
    }
}

@MainActor
private struct StockAccessScreen: View {
    @EnvironmentObject private var session: SessionStore

    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MediStockLogo()

                switch session.accessStatus {
                case .checking:
                    ProgressView("Vérification de l’accès…")

                    Text("Une connexion Internet est nécessaire.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                case .denied:
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundStyle(
                            MediStockTheme.primary
                        )

                    Text("Accès non autorisé")
                        .font(.title2.bold())

                    Text(
                        "Ton compte est connecté. Son accès au stock "
                        + "doit être autorisé par le responsable du projet."
                    )

                case .unavailable:
                    ErrorBanner(
                        message:
                            "Impossible de vérifier l’accès. "
                            + "Vérifie ta connexion puis réessaie."
                    )

                case .allowed:
                    EmptyView()
                }

                Button("Actualiser l’accès") {
                    session.refreshAccess()
                }
                .buttonStyle(.borderedProminent)

                Button("Se déconnecter") {
                    do {
                        try session.signOut()
                    } catch {
                        errorMessage =
                            "Déconnexion impossible. Réessaie."
                    }
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .mediStockScreen()
    }
}
