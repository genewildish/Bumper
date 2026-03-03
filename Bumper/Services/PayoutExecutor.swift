import Foundation

/// Protocol defining the boundary for payout execution.
/// Implementations handle the actual transfer mechanism (simulated, bank API, etc.).
protocol PayoutExecutor {
    /// Execute a payout transfer.
    /// - Parameters:
    ///   - amount: The amount to transfer
    ///   - debtName: The name of the debt being paid out
    ///   - date: The timestamp of the payout
    /// - Returns: A PayoutEvent representing the executed transfer
    func execute(amount: Double, debtName: String, at date: Date) -> PayoutEvent
}

/// Simulated payout executor that creates local payout events without real transfers.
/// This is the default/safe implementation that preserves existing behavior.
struct SimulatedPayoutExecutor: PayoutExecutor {
    func execute(amount: Double, debtName: String, at date: Date) -> PayoutEvent {
        PayoutEvent(
            amount: amount,
            triggeredAt: date,
            note: "Automatic transfer triggered after reaching the agreed threshold."
        )
    }
}
