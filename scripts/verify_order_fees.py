"""Run the app's actual fee arithmetic/serialization with lightweight Bill fixtures.
Usage: python3 scripts/verify_order_fees.py (requires the Swift toolchain).
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'SmartKiot/Models.swift').read_text()
def block(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]
fixture = '''
import Foundation
struct Bill {
    var total: Double
    var totalCost: Double = 300_000
    var orderFees: [OrderFee]? = nil
    var paidAmount: Double? = nil
    var isPaid = false
}
'''
tests = '''
let employee = UUID()
let shop = OrderFee(name: "Phí giao hàng", amount: 30_000)
let customer = OrderFee(name: "Phí chành xe", amount: 30_000, bearer: "customer", funding: "company")
let direct = OrderFee(name: "Phí giao hàng", amount: 30_000, bearer: "customer", funding: "customer")
assert(shop.isValid && customer.isValid && direct.isValid)
let original = Bill(total: 500_000)
assert(original.salesRevenue == 500_000 && original.shopFeeTotal == 0)
let shopBill = Bill(total: 500_000, orderFees: [shop])
assert(shopBill.salesRevenue == 500_000 && shopBill.revenueAfterFees == 470_000)
let customerBill = Bill(total: 530_000, orderFees: [customer], paidAmount: 530_000, isPaid: true)
assert(customerBill.salesRevenue == 500_000 && customerBill.receivedCustomerFees == 30_000)
let halfPaid = Bill(total: 530_000, orderFees: [customer], paidAmount: 265_000, isPaid: true)
assert(halfPaid.receivedCustomerFees == 15_000)
let directBill = Bill(total: 500_000, orderFees: [direct])
assert(directBill.salesRevenue == 500_000 && directBill.customerFeeTotal == 0)
let mixed = Bill(total: 530_000, orderFees: [shop, customer])
assert(mixed.revenueAfterFees == 470_000 && mixed.shopFeeTotal == 30_000)
assert(!OrderFee(name: "Invalid", amount: 1, funding: "customer").isValid)
assert(!OrderFee(name: "Invalid", amount: 1, funding: "employee").isValid)
assert(!OrderFee(name: "Invalid", amount: -1).isValid)
assert(!OrderFee(name: "Invalid", amount: .infinity).isValid)
let advance = OrderFee(name: "Ứng trước", amount: 30_000, bearer: "customer", funding: "employee", employeeID: employee, employeeName: "An")
let encoded = try JSONEncoder().encode([advance, shop])
let decoded = try JSONDecoder().decode([OrderFee].self, from: encoded)
assert(decoded == [advance, shop])
assert(decoded[0].employeeID == employee)
assert(Bill(total: 530_000, orderFees: [advance]).salesRevenue == customerBill.salesRevenue)
print("PASS: shop/customer/direct fees, mixed fees, partial receipts, invalid fees, employee identity and JSON round trip")
'''
with tempfile.TemporaryDirectory(prefix='order-fees-') as directory:
    swift_file = Path(directory) / 'main.swift'
    swift_file.write_text(fixture + block('struct OrderFee:') + '\n' + block('extension Bill {\n    var fees:') + tests)
    subprocess.run(['xcrun', 'swift', '-module-cache-path', directory + '/cache', str(swift_file)], check=True)
