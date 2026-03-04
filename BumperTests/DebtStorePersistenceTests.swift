import XCTest
@testable import Bumper

@MainActor
final class DebtStorePersistenceTests: XCTestCase {
    /// Creates an isolated per-test state file so tests do not share persisted data.
    private func makeStorageURL() -> URL {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("DebtStorePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("state.json")
    }
    /// Removes the temporary test directory after each test to avoid leftovers.

    private func cleanupStorageDirectory(for storageURL: URL) {
        let directory = storageURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: directory)
    }
    /// Clears the default seeded debt so each scenario can control initial state explicitly.

    private func removeAllDebts(in store: DebtStore) {
        for debt in store.debts {
            store.removeDebt(debtID: debt.id)
        }
    }
    /// Verifies settings + added debts survive a full store reinitialization from disk.

    func testAddDebtAndSettingsPersistAcrossReload() {
        let storageURL = makeStorageURL()
        defer { cleanupStorageDirectory(for: storageURL) }

        var store = DebtStore(storageURL: storageURL)
        removeAllDebts(in: store)
        // Persist both settings and debt data, then construct a fresh store at same URL.

        let expectedSettings = AppSettings(
            debtorName: "Alex",
            creditorName: "Sam",
            defaultThreshold: 42.0,
            monetizationOption: .ads
        )
        store.settings = expectedSettings
        store.addDebt(name: "Coffee runs", incrementAmount: 1.25, payoutThreshold: 10.0)

        store = DebtStore(storageURL: storageURL)

        XCTAssertEqual(store.settings, expectedSettings)
        XCTAssertEqual(store.debts.count, 1)
        XCTAssertEqual(store.debts.first?.name, "Coffee runs")
        XCTAssertEqual(store.debts.first?.incrementAmount, 1.25, accuracy: 0.0001)
        XCTAssertEqual(store.debts.first?.payoutThreshold, 10.0, accuracy: 0.0001)
    }
    /// Verifies deletes are durable and removed records do not come back after reload.

    func testRemovedDebtDoesNotReturnAfterReload() {
        let storageURL = makeStorageURL()
        defer { cleanupStorageDirectory(for: storageURL) }

        var store = DebtStore(storageURL: storageURL)
        removeAllDebts(in: store)

        store.addDebt(name: "Arcade", incrementAmount: 2.0, payoutThreshold: 8.0)
        store.addDebt(name: "Pizza", incrementAmount: 3.0, payoutThreshold: 12.0)

        let removedDebtID = store.debts.first(where: { $0.name == "Arcade" })?.id
        XCTAssertNotNil(removedDebtID)
        if let removedDebtID {
            store.removeDebt(debtID: removedDebtID)
        }

        store = DebtStore(storageURL: storageURL)

        XCTAssertEqual(store.debts.count, 1)
        XCTAssertNil(store.debts.first(where: { $0.name == "Arcade" }))
        XCTAssertEqual(store.debts.first?.name, "Pizza")
    }
    /// Verifies payout-side effects from bumping are fully persisted.

    func testPayoutTriggeringBumpStatePersistsAcrossReload() {
        let storageURL = makeStorageURL()
        defer { cleanupStorageDirectory(for: storageURL) }

        var store = DebtStore(storageURL: storageURL)
        removeAllDebts(in: store)

        store.addDebt(name: "Arcade tokens", incrementAmount: 5.0, payoutThreshold: 10.0)
        let debtID = store.debts[0].id

        store.bump(debtID: debtID)
        store.bump(debtID: debtID) // triggers payout at threshold

        store = DebtStore(storageURL: storageURL)
        let reloadedDebt = store.debts.first(where: { $0.id == debtID })

        XCTAssertNotNil(reloadedDebt)
        XCTAssertEqual(reloadedDebt?.bumpCount, 2)
        XCTAssertEqual(reloadedDebt?.balance, 0.0, accuracy: 0.0001)
        XCTAssertEqual(reloadedDebt?.totalPaidOut, 10.0, accuracy: 0.0001)
        XCTAssertEqual(reloadedDebt?.payoutEvents.count, 1)
        XCTAssertEqual(reloadedDebt?.payoutEvents.first?.amount, 10.0, accuracy: 0.0001)
    }
    /// Verifies load fallback behavior for missing/corrupt persisted state remains non-fatal.

    func testMissingOrInvalidStateFallsBackToDefaultsAndSeedBehavior() {
        let missingStorageURL = makeStorageURL()
        defer { cleanupStorageDirectory(for: missingStorageURL) }
        // Missing file path should behave like first launch (defaults + seed debt).

        let missingStore = DebtStore(storageURL: missingStorageURL)
        XCTAssertEqual(missingStore.settings, AppSettings())
        XCTAssertEqual(missingStore.debts.count, 1)
        XCTAssertEqual(missingStore.debts.first?.name, "Pinball machine games")

        let invalidStorageURL = makeStorageURL()
        defer { cleanupStorageDirectory(for: invalidStorageURL) }

        let invalidJSON = Data("not valid json".utf8)
        try? invalidJSON.write(to: invalidStorageURL, options: .atomic)
        // Corrupt JSON should also recover to defaults + seed debt.

        let invalidStore = DebtStore(storageURL: invalidStorageURL)
        XCTAssertEqual(invalidStore.settings, AppSettings())
        XCTAssertEqual(invalidStore.debts.count, 1)
        XCTAssertEqual(invalidStore.debts.first?.name, "Pinball machine games")
    }
}
