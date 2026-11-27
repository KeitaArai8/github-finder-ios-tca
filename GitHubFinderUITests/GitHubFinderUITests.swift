//
//  GitHubFinderUITests.swift
//  GitHubFinderUITests
//
//  Created by k-arai on 2026/04/12.
//

import XCTest

final class GitHubFinderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - CUJ: 起動時のタブバー・初期画面

    @MainActor
    func testLaunch_showsAllTabsAndSearchIsSelectedByDefault() throws {
        let app = XCUIApplication()
        app.launch()

        // 3タブすべてがタブバーに表示されている
        XCTAssertTrue(app.tabBars.buttons["検索"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["お気に入り"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)

        // 検索タブがデフォルト選択され、EmptyStateのタイトルが表示される
        XCTAssertTrue(app.staticTexts["リポジトリを検索"].waitForExistence(timeout: 2))
    }

    // MARK: - CUJ: 3タブ間の画面遷移

    @MainActor
    func testTabSwitching_navigatesAcrossAllThreeTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // お気に入りタブに切替 → ナビゲーションタイトル "お気に入り" が表示
        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.navigationBars["お気に入り"].waitForExistence(timeout: 2))

        // 設定タブに切替 → "プライバシーポリシー" ボタンが表示
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["プライバシーポリシー"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["利用規約"].exists)

        // 検索タブに戻る → ナビゲーションタイトル "検索" が表示
        app.tabBars.buttons["検索"].tap()
        XCTAssertTrue(app.navigationBars["検索"].waitForExistence(timeout: 2))
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
