import Foundation

@MainActor
final class DebtStore: ObservableObject {
    @Published private(set) var debts: [MicroDebt] = []
    @Published var settings: AppSettings {
        didSet { persist() }
    }
    @Published var payoutBannerMessage: String?

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(storageURL: URL? = nil) {
        self.settings = AppSettings()
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        load()
        seedIfEmpty()
    }

    func addDebt(name: String, incrementAmount: Double, payoutThreshold: Double? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let clampedIncrement = min(max(incrementAmount, 0.25), 5.0)
        let resolvedThreshold = max(payoutThreshold ?? settings.defaultThreshold, 5.0)

        let debt = MicroDebt(
            name: trimmedName,
            incrementAmount: clampedIncrement,
            payoutThreshold: resolvedThreshold
        )
        debts.insert(debt, at: 0)
        persist()
    }

    func bump(debtID: UUID) {
        guard let index = debts.firstIndex(where: { $0.id == debtID }) else { return }

        var debt = debts[index]
        let result = PayoutProcessor.bump(&debt)
        debts[index] = debt

        if case .paidOut(let payout) = result {
            payoutBannerMessage = "Auto-paid \(payout.amount.asCurrency()) for “\(debt.name)”."
        }
        persist()
    }

    func removeDebt(debtID: UUID) {
        debts.removeAll(where: { $0.id == debtID })
        persist()
    }

    private func seedIfEmpty() {
        guard debts.isEmpty else { return }
        debts = [
            MicroDebt(
                name: "Pinball machine games",
                incrementAmount: 2.00,
                payoutThreshold: settings.defaultThreshold
            )
        ]
        persist()
    }

    private func persist() {
        let state = PersistedState(debts: debts, settings: settings)
        do {
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Keep failures non-fatal in this scaffold.
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            let state = try decoder.decode(PersistedState.self, from: data)
            debts = state.debts
            settings = state.settings
        } catch {
            debts = []
            settings = AppSettings()
        }
    }

    private static func defaultStorageURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        let bumperDirectory = baseDirectory.appendingPathComponent("Bumper", isDirectory: true)
        try? fileManager.createDirectory(at: bumperDirectory, withIntermediateDirectories: true)

        return bumperDirectory.appendingPathComponent("state.json")
    }
}

private struct PersistedState: Codable {
    var debts: [MicroDebt]
    var settings: AppSettings
}
