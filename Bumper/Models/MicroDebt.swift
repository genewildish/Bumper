import Foundation

struct PayoutEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var amount: Double
    var triggeredAt: Date
    var note: String

    init(id: UUID = UUID(), amount: Double, triggeredAt: Date, note: String) {
        self.id = id
        self.amount = amount
        self.triggeredAt = triggeredAt
        self.note = note
    }
}

struct MicroDebt: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var incrementAmount: Double
    var payoutThreshold: Double
    var balance: Double
    var totalPaidOut: Double
    var bumpCount: Int
    var createdAt: Date
    var lastBumpedAt: Date?
    var payoutEvents: [PayoutEvent]

    init(
        id: UUID = UUID(),
        name: String,
        incrementAmount: Double,
        payoutThreshold: Double,
        balance: Double = 0,
        totalPaidOut: Double = 0,
        bumpCount: Int = 0,
        createdAt: Date = Date(),
        lastBumpedAt: Date? = nil,
        payoutEvents: [PayoutEvent] = []
    ) {
        self.id = id
        self.name = name
        self.incrementAmount = incrementAmount
        self.payoutThreshold = payoutThreshold
        self.balance = balance
        self.totalPaidOut = totalPaidOut
        self.bumpCount = bumpCount
        self.createdAt = createdAt
        self.lastBumpedAt = lastBumpedAt
        self.payoutEvents = payoutEvents
    }

    var progress: Double {
        guard payoutThreshold > 0 else { return 0 }
        return min(balance / payoutThreshold, 1)
    }
}
