#!/usr/bin/env swift
import Foundation

enum BillPaymentMath {
    static func effectiveDebt(total: Double, isPaid: Bool, paidAmount: Double?, debtAmount: Double?) -> Double {
        if let debt = debtAmount, debt > 0 {
            return debt
        }
        if !isPaid {
            return max(0, total - (paidAmount ?? 0))
        }
        return 0
    }

    static func vietQRCollectAmount(total: Double, isPaid: Bool, paidAmount: Double?, debtAmount: Double?) -> Double {
        let remaining = effectiveDebt(total: total, isPaid: isPaid, paidAmount: paidAmount, debtAmount: debtAmount)
        return remaining > 0 ? remaining : total
    }
}

enum ImportBatchMark {
    static func nextNumber(current: Int?, increment: Bool, quantity: Int, enabled: Bool) -> Int? {
        guard increment, quantity > 0, enabled else { return current }
        return (current ?? 0) + 1
    }

    static func initialNumber(increment: Bool, quantity: Int, enabled: Bool) -> Int? {
        (increment && quantity > 0 && enabled) ? 1 : nil
    }
}

func assertEq<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    if actual != expected {
        fputs("FAIL \(label): got \(actual), expected \(expected)\n", stderr)
        exit(1)
    }
    print("PASS \(label)")
}

// Unpaid bill: QR must request the full total, not 0.
assertEq(
    BillPaymentMath.vietQRCollectAmount(total: 100_000, isPaid: false, paidAmount: 0, debtAmount: 100_000),
    100_000,
    "unpaid QR uses total"
)

// Partial payment: QR must request remaining debt, not the amount already paid.
assertEq(
    BillPaymentMath.vietQRCollectAmount(total: 100_000, isPaid: false, paidAmount: 30_000, debtAmount: 70_000),
    70_000,
    "partial QR uses remaining debt"
)

// Same partial case without stored debtAmount.
assertEq(
    BillPaymentMath.vietQRCollectAmount(total: 100_000, isPaid: false, paidAmount: 30_000, debtAmount: nil),
    70_000,
    "partial QR derives remaining from total - paid"
)

// Fully paid: remaining is 0, QR reprints the bill total.
assertEq(
    BillPaymentMath.vietQRCollectAmount(total: 100_000, isPaid: true, paidAmount: 100_000, debtAmount: nil),
    100_000,
    "paid-in-full QR uses total"
)

assertEq(ImportBatchMark.nextNumber(current: 2, increment: true, quantity: 10, enabled: true), 3, "new restock increments batch")
assertEq(ImportBatchMark.nextNumber(current: 2, increment: false, quantity: 10, enabled: true), 2, "edit restock does not increment")
assertEq(ImportBatchMark.nextNumber(current: 2, increment: true, quantity: 0, enabled: true), 2, "zero qty does not increment")
assertEq(ImportBatchMark.nextNumber(current: 2, increment: true, quantity: 10, enabled: false), 2, "disabled does not increment")
assertEq(ImportBatchMark.initialNumber(increment: true, quantity: 5, enabled: true), 1, "new product starts at batch 1")
assertEq(ImportBatchMark.initialNumber(increment: false, quantity: 5, enabled: true), nil as Int?, "edit does not stamp batch 1 on new name")

print("All checks passed.")
