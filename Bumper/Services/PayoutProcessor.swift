import Foundation

enum PayoutResult: Equatable {
    case none
    case paidOut(PayoutEvent)
}

enum PayoutProcessor {
    static func bump(_ debt: inout MicroDebt, at date: Date = Date()) -> PayoutResult {
        debt.bumpCount += 1
        debt.balance += debt.incrementAmount
        debt.lastBumpedAt = date

        guard debt.balance + 0.000_001 >= debt.payoutThreshold else {
            return .none
        }

        let payoutAmount = debt.balance
        debt.balance = 0
        debt.totalPaidOut += payoutAmount

        let payout = PayoutEvent(
            amount: payoutAmount,
            triggeredAt: date,
            note: "Automatic transfer triggered after reaching the agreed threshold."
        )
        debt.payoutEvents.insert(payout, at: 0)
        return .paidOut(payout)
    }
}
