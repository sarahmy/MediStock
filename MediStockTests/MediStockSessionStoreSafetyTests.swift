//
//  MediStockSessionStoreSafetyTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import XCTest
@testable import MediStock

/// Tests de sécurité des validations locales.
/// Aucune connexion ni écriture Firebase.
final class MediStockSessionStoreSafetyTests: XCTestCase {

    // MARK: - État initial

    @MainActor
    func testNewSessionStartsInCheckingState() {
        let session = SessionStore()

        XCTAssertNil(session.user)
        XCTAssertTrue(session.isChecking)
        XCTAssertEqual(session.accessStatus, .checking)
    }

    // MARK: - Connexion

    @MainActor
    func testSignInRejectsWhitespaceOnlyEmail() async {
        let session = SessionStore()

        await expectLocalError(
            "Renseigne l'email et le mot de passe."
        ) {
            try await session.signIn(
                email: " \n  \t ",
                password: "abcdef"
            )
        }
    }

    @MainActor
    func testSignInRejectsEmptyPasswordWithEmail() async {
        let session = SessionStore()

        await expectLocalError(
            "Renseigne l'email et le mot de passe."
        ) {
            try await session.signIn(
                email: "  alice@example.com  ",
                password: ""
            )
        }
    }

    // MARK: - Inscription

    @MainActor
    func testSignUpRejectsEmailContainingSpaces() async {
        let session = SessionStore()

        await expectLocalError(
            "Vérifie le format de l'adresse email."
        ) {
            try await session.signUp(
                email: "alice test@example.com",
                password: "abcdef",
                confirmation: "abcdef"
            )
        }
    }

    @MainActor
    func testSignUpRejectsMissingAtSignBeforeCheckingPassword() async {
        let session = SessionStore()

        await expectLocalError(
            "Vérifie le format de l'adresse email."
        ) {
            try await session.signUp(
                email: "adresse-invalide",
                password: "123",
                confirmation: "autre"
            )
        }
    }

    @MainActor
    func testSignUpRejectsShortPasswordBeforeCheckingConfirmation() async {
        let session = SessionStore()

        await expectLocalError(
            "Le mot de passe doit contenir au moins 6 caractères."
        ) {
            try await session.signUp(
                email: "alice@example.com",
                password: "123",
                confirmation: "different"
            )
        }
    }

    // MARK: - Mot de passe oublié

    @MainActor
    func testPasswordResetRejectsWhitespaceOnlyEmail() async {
        let session = SessionStore()

        await expectLocalError(
            "Renseigne ton adresse email."
        ) {
            try await session.resetPassword(
                email: "  \n\t  "
            )
        }
    }

    @MainActor
    func testPasswordResetRejectsAddressWithoutAtSign() async {
        let session = SessionStore()

        await expectLocalError(
            "Renseigne ton adresse email."
        ) {
            try await session.resetPassword(
                email: "invalide"
            )
        }
    }

    // MARK: - Vérification commune

    @MainActor
    private func expectLocalError(
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: @MainActor () async throws -> Void
    ) async {
        do {
            try await operation()

            XCTFail(
                "Une erreur de validation locale était attendue.",
                file: file,
                line: line
            )
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                expected,
                file: file,
                line: line
            )
        }
    }
}
