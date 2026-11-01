//
//  MediStockUITestsLaunchTests.swift
//  MediStockUITests
//
//  Created by Vincent Saluzzo on 28/05/2024.
//


import XCTest

/// Un test de lancement qui vérifie réellement l'écran présenté.
/// Il n'exige aucun compte Firebase valide et ne modifie pas les stocks.
final class MediStockUITestsLaunchTests: XCTestCase {


    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchDisplaysLoginScreen() {
        let app = XCUIApplication()
        app.launchEnvironment["MEDISTOCK_AUTH_UI_SCREEN"] = "login"
        app.launch()
        defer { app.terminate() }

        let title = app.staticTexts["auth.screen.login"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Écran de connexion absent")
        XCTAssertTrue(app.textFields["auth.email"].exists)
        XCTAssertTrue(app.secureTextFields["auth.password"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MediStock - écran de connexion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testLaunchDisplaysSignupScreen() {
        let app = XCUIApplication()
        app.launchEnvironment["MEDISTOCK_AUTH_UI_SCREEN"] = "signup"
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.staticTexts["auth.screen.signup"].waitForExistence(timeout: 15)
        )
        XCTAssertTrue(app.secureTextFields["auth.confirmation"].exists)
    }
}
