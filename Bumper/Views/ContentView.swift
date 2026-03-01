import SwiftUI

struct ContentView: View {
    @StateObject private var store = DebtStore()
    @State private var showingNewDebtSheet = false

    var body: some View {
        NavigationStack {
            List {
                introSection
                agreementSection
                debtSection
                payoutHistorySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bumper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewDebtSheet = true
                    } label: {
                        Label("Add debt", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewDebtSheet) {
                AddDebtSheetView(defaultThreshold: store.settings.defaultThreshold) { name, incrementAmount, threshold in
                    store.addDebt(name: name, incrementAmount: incrementAmount, payoutThreshold: threshold)
                }
            }
            .alert("Auto-payout complete", isPresented: payoutAlertIsPresented) {
                Button("Nice") {
                    store.payoutBannerMessage = nil
                }
            } message: {
                Text(store.payoutBannerMessage ?? "")
            }
        }
    }

    private var payoutAlertIsPresented: Binding<Bool> {
        Binding(
            get: { store.payoutBannerMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    store.payoutBannerMessage = nil
                }
            }
        )
    }

    private var introSection: some View {
        Section {
            Text("Track playful IOUs between friends and family, then auto-pay once you hit your agreed threshold.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var agreementSection: some View {
        Section("Agreement") {
            TextField("Debtor", text: debtorNameBinding)
            TextField("Creditor", text: creditorNameBinding)

            Stepper(value: defaultThresholdBinding, in: 5 ... 250, step: 5) {
                HStack {
                    Text("Default threshold")
                    Spacer()
                    Text(store.settings.defaultThreshold.asCurrency())
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Monetization", selection: monetizationBinding) {
                ForEach(MonetizationOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Text(store.settings.monetizationOption.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var debtSection: some View {
        Section("Micro-debts") {
            if store.debts.isEmpty {
                Text("No debts yet. Tap + to add your first one.")
                    .foregroundStyle(.secondary)
            }

            ForEach(store.debts) { debt in
                DebtCardView(
                    debt: debt,
                    debtorName: store.settings.debtorName,
                    creditorName: store.settings.creditorName
                ) {
                    store.bump(debtID: debt.id)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        store.removeDebt(debtID: debt.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var payoutHistorySection: some View {
        Section("Recent auto-payouts") {
            if payoutFeed.isEmpty {
                Text("No payouts yet. Bump a debt until it reaches the threshold.")
                    .foregroundStyle(.secondary)
            }

            ForEach(payoutFeed) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.debtName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(item.event.amount.asCurrency()) paid at \(item.event.triggeredAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var payoutFeed: [PayoutFeedItem] {
        store.debts
            .flatMap { debt in
                debt.payoutEvents.map { PayoutFeedItem(debtName: debt.name, event: $0) }
            }
            .sorted { $0.event.triggeredAt > $1.event.triggeredAt }
            .prefix(10)
            .map { $0 }
    }

    private var debtorNameBinding: Binding<String> {
        Binding(
            get: { store.settings.debtorName },
            set: { store.settings.debtorName = $0 }
        )
    }

    private var creditorNameBinding: Binding<String> {
        Binding(
            get: { store.settings.creditorName },
            set: { store.settings.creditorName = $0 }
        )
    }

    private var defaultThresholdBinding: Binding<Double> {
        Binding(
            get: { store.settings.defaultThreshold },
            set: { store.settings.defaultThreshold = $0 }
        )
    }

    private var monetizationBinding: Binding<MonetizationOption> {
        Binding(
            get: { store.settings.monetizationOption },
            set: { store.settings.monetizationOption = $0 }
        )
    }
}

private struct PayoutFeedItem: Identifiable {
    let debtName: String
    let event: PayoutEvent
    var id: UUID { event.id }
}
