import Foundation

struct AppSettings: Codable, Equatable {
    var debtorName: String = "Debtor"
    var creditorName: String = "Creditor"
    var defaultThreshold: Double = 25.0
    var monetizationOption: MonetizationOption = .upfrontFee
}
