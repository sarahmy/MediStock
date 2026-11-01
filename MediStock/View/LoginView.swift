
import SwiftUI

@MainActor
struct LoginView: View {
    var body: some View {
        NavigationStack {
            AuthenticationForm(signup: false)
        }
    }
}

@MainActor
struct AuthenticationForm: View {
    let signup: Bool

    @EnvironmentObject private var session: SessionStore

    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    @State private var busy = false
    @State private var message = ""
    @State private var failed = false
    @State private var showingSignup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                MediStockLogo()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)

                Text(signup ? "Créer un compte" : "Connexion")
                    .font(.title2.bold())
                    .accessibilityIdentifier(
                        signup
                            ? "auth.screen.signup"
                            : "auth.screen.login"
                    )

                VStack(alignment: .leading, spacing: 16) {

                    TextField("Adresse email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("auth.email")

                    PasswordInput(
                        title: "Mot de passe",
                        text: $password,
                        newPassword: signup,
                        identifier: "auth.password"
                    )

                    if signup {
                        PasswordInput(
                            title: "Confirmer le mot de passe",
                            text: $confirmation,
                            newPassword: true,
                            identifier: "auth.confirmation"
                        )

                        Text(
                            "Au moins 6 caractères. Choisis un mot de passe long et unique."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.06))
                }
                .disabled(busy)

                if !message.isEmpty {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(
                            failed ? .red : .primary
                        )
                        .accessibilityIdentifier("auth.feedback")
                        .accessibilityLabel(message)
                }

                if busy {
                    ProgressView("Traitement…")
                        .frame(maxWidth: .infinity)
                }

                if !signup {
                    Button {
                        showingSignup = true
                    } label: {
                        Text("Créer un compte")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("auth.signup")

                    Button {
                        resetPassword()
                    } label: {
                        Text("Mot de passe oublié ?")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("auth.reset")
                    .disabled(busy)
                }
            }
            .frame(maxWidth: 500)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                submit()
            } label: {
                Text(
                    signup
                        ? "Créer mon compte"
                        : "Se connecter"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("auth.submit")
            .disabled(busy)
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .background {
            MediStockBackground()
                .ignoresSafeArea()
        }
        .tint(MediStockTheme.primary)
        .navigationTitle(
            signup ? "Inscription" : "Bienvenue"
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingSignup) {
            AuthenticationForm(signup: true)
        }
        .onDisappear {
            password = ""
            confirmation = ""
        }
    }

    private func submit() {
        guard !busy else { return }

        busy = true
        message = ""
        failed = false

        Task {
            defer { busy = false }

            do {
                if signup {
                    try await session.signUp(
                        email: email,
                        password: password,
                        confirmation: confirmation
                    )
                } else {
                    try await session.signIn(
                        email: email,
                        password: password
                    )
                }

                password = ""
                confirmation = ""

            } catch {
                failed = true
                message = error.localizedDescription
            }
        }
    }

    private func resetPassword() {
        guard !busy else { return }

        let trimmedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedEmail.contains("@") else {
            failed = true
            message = "Renseigne ton adresse email."
            return
        }

        busy = true
        message = ""
        failed = false

        Task {
            defer { busy = false }

            do {
                try await session.resetPassword(email: email)

                message =
                    "Si un compte correspond à cette adresse, un email sera envoyé."

            } catch {
                failed = true
                message = error.localizedDescription
            }
        }
    }
}
