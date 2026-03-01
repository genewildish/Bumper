import SwiftUI

struct DebtCardView: View {
    let debt: MicroDebt
    let debtorName: String
    let creditorName: String
    let onBump: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(debt.name)
                    .font(.headline)
                Spacer()
                Text(debt.balance.asCurrency())
                    .font(.title3.weight(.semibold))
            }

            Text("\(debtorName) owes \(creditorName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: debt.progress) {
                Text("Auto-pay at \(debt.payoutThreshold.asCurrency())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Bump \(debt.incrementAmount.asCurrency())") {
                onBump()
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)

            if let lastPayout = debt.payoutEvents.first {
                Text("Last payout: \(lastPayout.amount.asCurrency()) on \(lastPayout.triggeredAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
