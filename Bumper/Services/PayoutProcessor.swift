import Foundation

enum PayoutResult: Equatable {
    case none
    case paidOut(PayoutEvent)
}

enum PayoutProcessor {
    /// Process a bump with the default simulated executor.
    /// This preserves existing behavior for backward compatibility.
    static func bump(_ debt: inout MicroDebt, at date: Date = Date()) -> PayoutResult {
        bump(&debt, executor: SimulatedPayoutExecutor(), at: date)
    }
    
    /// Process a bump with a custom executor.
    /// - Parameters:
    ///   - debt: The debt to bump (modified in-place)
    ///   - executor: The payout executor to use when threshold is met
    ///   - date: The timestamp for this bump
    /// - Returns: PayoutResult indicating whether a payout occurred
    static func bump(
        _ debt: inout MicroDebt,
        executor: PayoutExecutor,
        at date: Date = Date()
    ) -> PayoutResult {
        debt.bumpCount += 1
        debt.balance += debt.incrementAmount
        debt.lastBumpedAt = date

        guard debt.balance + 0.000_001 >= debt.payoutThreshold else {
            return .none
        }

        let payoutAmount = debt.balance
        debt.balance = 0
        debt.totalPaidOut += payoutAmount

        let payout = executor.execute(
            amount: payoutAmount,
            debtName: debt.name,
            at: date
        )
        debt.payoutEvents.insert(payout, at: 0)
        return .paidOut(payout)
    }
}
