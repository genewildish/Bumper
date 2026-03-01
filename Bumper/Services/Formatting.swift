import Foundation

enum NumberFormatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func decimal(maximumFractionDigits: Int = 2) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0
        formatter.locale = .current
        return formatter
    }
}

extension Double {
    func asCurrency() -> String {
        NumberFormatters.currency.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    func asNumber(maximumFractionDigits: Int = 2) -> String {
        NumberFormatters.decimal(maximumFractionDigits: maximumFractionDigits)
            .string(from: NSNumber(value: self)) ?? "0"
    }
}
