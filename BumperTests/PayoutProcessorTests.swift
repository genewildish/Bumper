import XCTest
@testable import Bumper

final class PayoutProcessorTests: XCTestCase {
    func testBumpDoesNotPayoutBeforeThreshold() {
        var debt = MicroDebt(
            name: "Pinball machine games",
            incrementAmount: 2.00,
            payoutThreshold: 25.00
        )

        let result = PayoutProcessor.bump(&debt, at: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result, .none)
        XCTAssertEqual(debt.balance, 2.00, accuracy: 0.0001)
        XCTAssertEqual(debt.totalPaidOut, 0.00, accuracy: 0.0001)
        XCTAssertEqual(debt.payoutEvents.count, 0)
        XCTAssertEqual(debt.bumpCount, 1)
    }

    func testBumpPaysOutAtThreshold() {
        var debt = MicroDebt(
            name: "Coffee runs",
            incrementAmount: 5.00,
            payoutThreshold: 25.00,
            balance: 20.00
        )

        let result = PayoutProcessor.bump(&debt, at: Date(timeIntervalSince1970: 1_700_000_500))

        switch result {
        case .none:
            XCTFail("Expected payout when threshold is reached")
        case .paidOut(let event):
            XCTAssertEqual(event.amount, 25.00, accuracy: 0.0001)
            XCTAssertEqual(debt.payoutEvents.first, event)
        }

        XCTAssertEqual(debt.balance, 0.00, accuracy: 0.0001)
        XCTAssertEqual(debt.totalPaidOut, 25.00, accuracy: 0.0001)
    }

    func testBumpPaysOutEntireBalanceWhenCrossingThreshold() {
        var debt = MicroDebt(
            name: "Arcade tokens",
            incrementAmount: 3.00,
            payoutThreshold: 25.00,
            balance: 24.00
        )

        let result = PayoutProcessor.bump(&debt, at: Date(timeIntervalSince1970: 1_700_001_000))

        switch result {
        case .none:
            XCTFail("Expected payout when threshold is crossed")
        case .paidOut(let event):
            XCTAssertEqual(event.amount, 27.00, accuracy: 0.0001)
        }

        XCTAssertEqual(debt.balance, 0.00, accuracy: 0.0001)
        XCTAssertEqual(debt.totalPaidOut, 27.00, accuracy: 0.0001)
    }
}
