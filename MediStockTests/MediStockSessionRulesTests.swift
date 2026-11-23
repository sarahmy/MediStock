//
//  MediStockSessionRulesTests.swift
//  MediStockTests
//
//  Created by Sarah Maimoun on 23/11/2026.
//


import Foundation
import XCTest
@testable import MediStock

final class MediStockSessionRulesTests: XCTestCase {

    // MARK: - Connexion

    @MainActor
    func testSignInTrimsEmail() throws {
        let result = try SessionStoreRules.signInEmail(
            "  test@example.com \n",
            password: "secret"
        )
        XCTAssertEqual(result, "test@example.com")
    }

    @MainActor
    func testSignInRejectsEmptyEmail() {
        assertMessage("Renseigne l'email et le mot de passe.") {
            try SessionStoreRules.signInEmail("", password: "secret")
        }
    }

    @MainActor
    func testSignInRejectsWhitespaceOnlyEmail() {
        assertMessage("Renseigne l'email et le mot de passe.") {
            try SessionStoreRules.signInEmail(" \n ", password: "secret")
        }
    }

    @MainActor
    func testSignInRejectsEmptyPassword() {
        assertMessage("Renseigne l'email et le mot de passe.") {
            try SessionStoreRules.signInEmail(
                "test@example.com",
                password: ""
            )
        }
    }

    // MARK: - Inscription

    @MainActor
    func testSignUpTrimsEmail() throws {
        let result = try SessionStoreRules.signUpEmail(
            " test@example.com ",
            password: "secret",
            confirmation: "secret"
        )
        XCTAssertEqual(result, "test@example.com")
    }

    @MainActor
    func testSignUpRejectsEmailWithoutAtSign() {
        assertMessage("Vérifie le format de l'adresse email.") {
            try SessionStoreRules.signUpEmail(
                "adresse-invalide",
                password: "secret",
                confirmation: "secret"
            )
        }
    }

    @MainActor
    func testSignUpRejectsEmailContainingSpace() {
        assertMessage("Vérifie le format de l'adresse email.") {
            try SessionStoreRules.signUpEmail(
                "test @example.com",
                password: "secret",
                confirmation: "secret"
            )
        }
    }

    @MainActor
    func testSignUpRejectsShortPassword() {
        assertMessage("Le mot de passe doit contenir au moins 6 caractères.") {
            try SessionStoreRules.signUpEmail(
                "test@example.com",
                password: "12345",
                confirmation: "12345"
            )
        }
    }

    @MainActor
    func testSignUpAcceptsSixCharacterPassword() throws {
        let result = try SessionStoreRules.signUpEmail(
            "test@example.com",
            password: "123456",
            confirmation: "123456"
        )
        XCTAssertEqual(result, "test@example.com")
    }

    @MainActor
    func testSignUpRejectsDifferentConfirmation() {
        assertMessage("Les mots de passe ne correspondent pas.") {
            try SessionStoreRules.signUpEmail(
                "test@example.com",
                password: "secret1",
                confirmation: "secret2"
            )
        }
    }

    // MARK: - Réinitialisation

    @MainActor
    func testResetPasswordTrimsEmail() throws {
        let result = try SessionStoreRules.resetPasswordEmail(
            " test@example.com \n"
        )
        XCTAssertEqual(result, "test@example.com")
    }

    @MainActor
    func testResetPasswordRejectsEmailWithoutAtSign() {
        assertMessage("Renseigne ton adresse email.") {
            try SessionStoreRules.resetPasswordEmail("mauvaise-adresse")
        }
    }

    @MainActor
    func testResetPasswordRejectsWhitespaceOnlyEmail() {
        assertMessage("Renseigne ton adresse email.") {
            try SessionStoreRules.resetPasswordEmail("  \n ")
        }
    }

    // MARK: - Notifications de session

    @MainActor
    func testAccessCallbackAcceptsCurrentSession() {
        XCTAssertTrue(
            SessionStoreRules.acceptsAccessCallback(
                expectedGeneration: 2,
                currentGeneration: 2,
                expectedUID: "user-1",
                sessionUID: "user-1",
                authenticatedUID: "user-1"
            )
        )
    }

    @MainActor
    func testAccessCallbackRejectsOldGeneration() {
        XCTAssertFalse(
            SessionStoreRules.acceptsAccessCallback(
                expectedGeneration: 1,
                currentGeneration: 2,
                expectedUID: "user-1",
                sessionUID: "user-1",
                authenticatedUID: "user-1"
            )
        )
    }

    @MainActor
    func testAccessCallbackRejectsDifferentPublishedSession() {
        XCTAssertFalse(
            SessionStoreRules.acceptsAccessCallback(
                expectedGeneration: 2,
                currentGeneration: 2,
                expectedUID: "user-1",
                sessionUID: "user-2",
                authenticatedUID: "user-1"
            )
        )
    }

    @MainActor
    func testAccessCallbackRejectsDifferentFirebaseSession() {
        XCTAssertFalse(
            SessionStoreRules.acceptsAccessCallback(
                expectedGeneration: 2,
                currentGeneration: 2,
                expectedUID: "user-1",
                sessionUID: "user-1",
                authenticatedUID: "user-2"
            )
        )
    }

    @MainActor
    func testAccessCallbackRejectsNoAuthenticatedUser() {
        XCTAssertFalse(
            SessionStoreRules.acceptsAccessCallback(
                expectedGeneration: 2,
                currentGeneration: 2,
                expectedUID: "user-1",
                sessionUID: "user-1",
                authenticatedUID: nil
            )
        )
    }

    @MainActor
    func testAccessCallbackRejectsNoPublishedUser() {
        XCTAssertFalse(
            SessionStoreRules.acceptsAccessCallback(
                expectedGeneration: 2,
                currentGeneration: 2,
                expectedUID: "user-1",
                sessionUID: nil,
                authenticatedUID: "user-1"
            )
        )
    }

    // MARK: - Autorisations Firestore

    @MainActor
    func testServerEnabledGrantsAccess() {
        XCTAssertEqual(
            authorizationStatus(enabled: true),
            .allowed
        )
    }

    @MainActor
    func testServerDisabledDeniesAccess() {
        XCTAssertEqual(
            authorizationStatus(enabled: false),
            .denied
        )
    }

    @MainActor
    func testCachedEnabledDoesNotGrantAccess() {
        XCTAssertEqual(
            authorizationStatus(isFromCache: true, enabled: true),
            .checking
        )
    }

    @MainActor
    func testPendingWritesDoNotGrantAccess() {
        XCTAssertEqual(
            authorizationStatus(hasPendingWrites: true, enabled: true),
            .checking
        )
    }

    @MainActor
    func testCachedDisabledStillWaitsForServer() {
        XCTAssertEqual(
            authorizationStatus(isFromCache: true, enabled: false),
            .checking
        )
    }

    @MainActor
    func testMissingSnapshotIsUnavailable() {
        XCTAssertEqual(
            authorizationStatus(hasSnapshot: false, enabled: true),
            .unavailable
        )
    }

    @MainActor
    func testFirestoreErrorIsUnavailable() {
        XCTAssertEqual(
            authorizationStatus(hasError: true, enabled: true),
            .unavailable
        )
    }

    @MainActor
    func testErrorTakesPriorityOverCachedValue() {
        XCTAssertEqual(
            authorizationStatus(
                hasError: true,
                isFromCache: true,
                enabled: true
            ),
            .unavailable
        )
    }

    // MARK: - Helpers de test

    @MainActor
    private func assertMessage(
        _ expected: String,
        _ operation: () throws -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try operation()
            XCTFail("Une erreur de validation était attendue", file: file, line: line)
        } catch {
            XCTAssertEqual(
                userMessage(error),
                expected,
                file: file,
                line: line
            )
        }
    }

    @MainActor
    private func authorizationStatus(
        hasError: Bool = false,
        hasSnapshot: Bool = true,
        isFromCache: Bool = false,
        hasPendingWrites: Bool = false,
        enabled: Bool
    ) -> SessionStore.AccessStatus {
        SessionStoreRules.authorizationStatus(
            hasError: hasError,
            hasSnapshot: hasSnapshot,
            isFromCache: isFromCache,
            hasPendingWrites: hasPendingWrites,
            enabled: enabled
        )
    }
}
