import Foundation

enum MonetizationOption: String, CaseIterable, Codable, Identifiable {
    case upfrontFee = "Upfront fee"
    case perTransactionFee = "Per-transaction fee"
    case ads = "Advertisements"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .upfrontFee:
            return "Pay once and avoid fees later."
        case .perTransactionFee:
            return "Pay a small fee each time Bumper auto-pays."
        case .ads:
            return "Use Bumper free with occasional ad breaks."
        }
    }
}
