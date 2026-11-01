//
//  MediStockUITests.swift
//  MediStockUITests
//
//  Created by Vincent Saluzzo on 28/05/2024.
//


import XCTest

final class MediStockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func open(_ screen: String = "login") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MEDISTOCK_AUTH_UI_SCREEN"] = screen
        app.launch()
        return app
    }

    private func require(
        _ element: XCUIElement,
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: 10),
            "Élément absent : \(description)",
            file: file,
            line: line
        )
    }

    private func field(
        _ id: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let secure = app.secureTextFields[id]
        return secure.exists ? secure : app.textFields[id]
    }

    private func type(
        _ value: String,
        into id: String,
        in app: XCUIApplication
    ) {
        let target = field(id, in: app)
        require(target, id)
        XCTAssertTrue(
            target.isHittable,
            "Champ non accessible : \(id)"
        )
        target.tap()
        target.typeText(value)
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else {
            return
        }

        for name in ["Terminé", "Done", "Retour", "Return"] {
            let button = app.keyboards.buttons[name]
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }

        let scroll = app.scrollViews.firstMatch
        if scroll.exists && scroll.isHittable {
            scroll.swipeDown()
        }
    }

    private func submit(in app: XCUIApplication) {
        dismissKeyboard(in: app)

        let button = app.buttons["auth.submit"]
        require(button, "Bouton Valider")

        if !button.isHittable {
            let scroll = app.scrollViews.firstMatch
            if scroll.exists && scroll.isHittable {
                scroll.swipeUp()
            }
        }

        XCTAssertTrue(
            button.isHittable,
            "Bouton de validation inaccessible"
        )

        if button.isHittable {
            button.tap()
        }
    }

    private func assertFeedback(
        contains expected: String,
        in app: XCUIApplication
    ) {
        let identified = app.descendants(matching: .any)
            .matching(identifier: "auth.feedback")
            .firstMatch

        if identified.waitForExistence(timeout: 5) {
            XCTAssertTrue(
                identified.label.localizedCaseInsensitiveContains(expected),
                "Attendu : \(expected). Obtenu : \(identified.label)"
            )
            return
        }

        let byLabel = app.staticTexts
            .matching(
                NSPredicate(
                    format: "label CONTAINS[c] %@",
                    expected
                )
            )
            .firstMatch

        require(
            byLabel,
            "Message de validation : \(expected)"
        )
    }

    private func assertEyeState(
        _ identifier: String,
        visible: Bool,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = visible ? "visible" : "masqué"

        let query = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND value == %@",
                identifier + ".eye",
                expected
            )
        ).firstMatch

        XCTAssertTrue(
            query.waitForExistence(timeout: 10),
            "État attendu : \(expected). État observé : "
            + app.buttons[identifier + ".eye"].debugDescription,
            file: file,
            line: line
        )
    }

    // MARK: - Connexion

    func testLoginDisplaysRequiredControls() {
        let app = open()
        defer { app.terminate() }

        require(app.staticTexts["auth.screen.login"], "Titre Connexion")
        require(app.textFields["auth.email"], "Email")
        require(app.secureTextFields["auth.password"], "Mot de passe")
        require(app.buttons["auth.submit"], "Se connecter")
        require(app.buttons["auth.reset"], "Mot de passe oublié")
    }

    func testEmptyLoginDisplaysValidationError() {
        let app = open()
        defer { app.terminate() }

        submit(in: app)
        assertFeedback(
            contains: "Renseigne l'email et le mot de passe",
            in: app
        )
    }

    func testLoginWithoutPasswordDisplaysValidationError() {
        let app = open()
        defer { app.terminate() }

        type(
            "test@example.com",
            into: "auth.email",
            in: app
        )

        submit(in: app)
        assertFeedback(
            contains: "Renseigne l'email et le mot de passe",
            in: app
        )
    }

    func testPasswordRecoveryRequiresEmail() {
        let app = open()
        defer { app.terminate() }

        let reset = app.buttons["auth.reset"]
        require(reset, "Mot de passe oublié")

        if !reset.isHittable {
            let scroll = app.scrollViews.firstMatch
            if scroll.exists && scroll.isHittable {
                scroll.swipeUp()
            }
        }

        XCTAssertTrue(
            reset.isHittable,
            "Bouton Mot de passe oublié inaccessible"
        )

        reset.tap()

        assertFeedback(
            contains: "Renseigne ton adresse email",
            in: app
        )
    }

    func testPasswordVisibilityCanBeToggled() {
        let app = open()
        defer { app.terminate() }

        require(
            app.buttons["auth.password.eye"],
            "Bouton œil du mot de passe"
        )

        assertEyeState(
            "auth.password",
            visible: false,
            in: app
        )

        app.buttons["auth.password.eye"].tap()

        assertEyeState(
            "auth.password",
            visible: true,
            in: app
        )

        app.buttons["auth.password.eye"].tap()

        assertEyeState(
            "auth.password",
            visible: false,
            in: app
        )
    }

    // MARK: - Navigation

    func testSignupNavigationFromLogin() {
        let app = open()
        defer { app.terminate() }

        let button = app.buttons["auth.signup"]
        require(button, "Créer un compte")
        XCTAssertTrue(
            button.isHittable,
            "Bouton Créer un compte inaccessible"
        )

        button.tap()

        require(
            app.staticTexts["auth.screen.signup"],
            "Titre Inscription"
        )

        require(
            app.buttons["auth.confirmation.eye"],
            "Champ de confirmation"
        )
    }

    // MARK: - Inscription

    func testSignupDisplaysRequiredControls() {
        let app = open("signup")
        defer { app.terminate() }

        require(
            app.staticTexts["auth.screen.signup"],
            "Titre Inscription"
        )
        require(app.textFields["auth.email"], "Email")
        require(app.secureTextFields["auth.password"], "Mot de passe")
        require(app.secureTextFields["auth.confirmation"], "Confirmation")
    }

    func testSignupWithoutEmailIsRejected() {
        let app = open("signup")
        defer { app.terminate() }

        submit(in: app)
        assertFeedback(
            contains: "Vérifie le format de l'adresse email",
            in: app
        )
    }

    func testSignupWithInvalidEmailIsRejected() {
        let app = open("signup")
        defer { app.terminate() }

        type(
            "adresse-invalide",
            into: "auth.email",
            in: app
        )

        submit(in: app)
        assertFeedback(
            contains: "Vérifie le format de l'adresse email",
            in: app
        )
    }

    func testSignupRejectsShortPassword() {
        let app = open("signup")
        defer { app.terminate() }

        type(
            "test@example.com",
            into: "auth.email",
            in: app
        )

        let eye = app.buttons["auth.password.eye"]
        require(eye, "Afficher le mot de passe")
        eye.tap()

        assertEyeState(
            "auth.password",
            visible: true,
            in: app
        )

        let password = app.descendants(matching: .any)
            .matching(identifier: "auth.password")
            .firstMatch

        require(password, "Mot de passe")
        XCTAssertTrue(
            password.isHittable,
            "Champ mot de passe inaccessible"
        )

        password.tap()
        password.typeText("123")

        submit(in: app)

        assertFeedback(
            contains: "au moins 6 caractères",
            in: app
        )
    }

    func testSignupRequiresMatchingConfirmation() {
        let app = open("signup")
        defer { app.terminate() }

        type(
            "test@example.com",
            into: "auth.email",
            in: app
        )

        let passwordEye = app.buttons["auth.password.eye"]
        require(passwordEye, "Afficher le mot de passe")
        passwordEye.tap()

        let password = app.textFields["auth.password"]
        require(password, "Mot de passe visible")
        XCTAssertTrue(
            password.isHittable,
            "Champ mot de passe inaccessible"
        )

        password.tap()
        password.typeText("abcdef")

        let confirmationEye = app.buttons["auth.confirmation.eye"]
        require(confirmationEye, "Afficher la confirmation")
        confirmationEye.tap()

        let confirmation = app.textFields["auth.confirmation"]
        require(confirmation, "Confirmation visible")
        XCTAssertTrue(
            confirmation.isHittable,
            "Champ confirmation inaccessible"
        )

        confirmation.tap()
        confirmation.typeText("abcdefg")

        submit(in: app)

        assertFeedback(
            contains: "Les mots de passe ne correspondent pas",
            in: app
        )
    }

    func testConfirmationPasswordVisibilityCanBeToggled() {
        let app = open("signup")
        defer { app.terminate() }

        require(
            app.buttons["auth.confirmation.eye"],
            "Bouton œil de la confirmation"
        )

        assertEyeState(
            "auth.confirmation",
            visible: false,
            in: app
        )

        app.buttons["auth.confirmation.eye"].tap()

        assertEyeState(
            "auth.confirmation",
            visible: true,
            in: app
        )

        app.buttons["auth.confirmation.eye"].tap()

        assertEyeState(
            "auth.confirmation",
            visible: false,
            in: app
        )
    }

    // MARK: - Couverture des écrans principaux

    func testStockScreenLaunchesAndShowsNavigation() {
        let app = open("stock")
        defer { app.terminate() }

        require(
            app.navigationBars["Stock"],
            "Navigation Stock"
        )
        require(
            app.searchFields.firstMatch,
            "Recherche du stock"
        )
        require(
            app.buttons["Ajouter une référence"],
            "Ajout d'une référence"
        )
    }

    func testAislesScreenLaunches() {
        let app = open("aisles")
        defer { app.terminate() }

        require(
            app.navigationBars["Rayons"],
            "Navigation Rayons"
        )
    }

    func testHistoryScreenLaunchesAndExpandsFilters() {
        let app = open("history")
        defer { app.terminate() }

        require(
            app.navigationBars["Historique"],
            "Navigation Historique"
        )

        let filters = app.buttons["Filtres et tri"]
        require(filters, "Filtres et tri")

        if filters.isHittable {
            filters.tap()
        }
    }

    func testAccountScreenLaunches() {
        let app = open("account")
        defer { app.terminate() }

        require(
            app.navigationBars["Mon compte"],
            "Navigation Compte"
        )
        require(
            app.staticTexts["Adresse email"],
            "Adresse email"
        )
        require(
            app.buttons["Se déconnecter"],
            "Déconnexion"
        )
    }

    func testMedicineCreateScreenShowsLockedAisle() {
        let app = open("medicine-create")
        defer { app.terminate() }

        require(
            app.navigationBars["Nouvelle référence"],
            "Création de référence"
        )
        require(
            app.textFields["Nom de la référence"],
            "Nom de la référence"
        )

        let save = app.buttons["Enregistrer"]
        require(save, "Bouton Enregistrer")

        XCTAssertTrue(
            save.isEnabled,
            "Le rayon initial A1 devrait permettre l'enregistrement"
        )
    }

    func testMedicineEditScreenShowsExistingValues() {
        let app = open("medicine-edit")
        defer { app.terminate() }

        require(
            app.navigationBars["Modifier la fiche"],
            "Modification de référence"
        )

        let name = app.textFields["Nom de la référence"]
        require(name, "Nom existant")
        XCTAssertEqual(
            name.value as? String,
            "Paracétamol"
        )
    }

    func testMedicineDetailScreenHandlesUnavailableRepository() {
        let app = open("medicine-detail")
        defer { app.terminate() }

        require(
            app.navigationBars["Fiche médicament"],
            "Fiche médicament"
        )

        let retry = app.buttons["Actualiser"]
        XCTAssertTrue(
            retry.waitForExistence(timeout: 10)
        )
    }

    func testMainTabsExposeAllSections() {
        let app = open("main-tabs")
        defer { app.terminate() }

        for tab in ["Rayons", "Stock", "Historique", "Compte"] {
            require(
                app.tabBars.buttons[tab],
                "Onglet \(tab)"
            )
        }

        app.tabBars.buttons["Stock"].tap()
        require(
            app.navigationBars["Stock"],
            "Stock depuis les onglets"
        )

        app.tabBars.buttons["Historique"].tap()
        require(
            app.navigationBars["Historique"],
            "Historique depuis les onglets"
        )

        app.tabBars.buttons["Compte"].tap()
        require(
            app.navigationBars["Mon compte"],
            "Compte depuis les onglets"
        )
    }

    // MARK: - ContentView et thème

    func testContentViewLaunchesThroughRealRootFlow() {
        let app = open("content")
        defer { app.terminate() }

        XCTAssertTrue(
            app.staticTexts["auth.screen.login"]
                .waitForExistence(timeout: 10)
            ||
            app.tabBars.firstMatch
                .waitForExistence(timeout: 2)
            ||
            app.staticTexts["Accès non autorisé"]
                .waitForExistence(timeout: 2)
            ||
            app.buttons["Actualiser l’accès"]
                .waitForExistence(timeout: 2)
        )
    }

    func testThemeShowcaseCoversSharedComponents() {
        let app = open("theme-showcase")
        defer { app.terminate() }

        require(
            app.navigationBars["Coverage Theme"],
            "Écran de couverture du thème"
        )
        require(
            app.staticTexts["MediStock"],
            "Logo MediStock"
        )
        require(
            app.staticTexts["Erreur de démonstration"],
            "Bannière d'erreur"
        )

        let secure = app.secureTextFields["coverage.password"]
        require(secure, "Champ mot de passe partagé")

        let eye = app.buttons["coverage.password.eye"]
        require(eye, "Bouton œil partagé")

        eye.tap()
        require(
            app.textFields["coverage.password"],
            "Mot de passe visible"
        )

        eye.tap()
        require(
            app.secureTextFields["coverage.password"],
            "Mot de passe masqué"
        )
    }
}
