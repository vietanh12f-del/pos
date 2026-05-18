import Foundation
import SwiftUI

// MARK: - Financial Data Models

struct DailyFinancialStats: Identifiable, Codable {
    var id: Date { date }
    let date: Date
    var revenue: Double = 0
    var cogs: Double = 0
    var operatingCosts: Double = 0
    var incurredFees: Double = 0
    
    var grossProfit: Double {
        revenue - cogs
    }
    
    var netProfit: Double {
        grossProfit - operatingCosts // - incurredFees (Removed as requested)
    }
    
    var profitMargin: Double {
        guard revenue > 0 else { return 0 }
        return (netProfit / revenue) * 100
    }
}

enum ReportDateRange: Hashable {
    case today
    case thisWeek
    case thisMonth
    case custom(start: Date, end: Date)
    
    var title: String {
        switch self {
        case .today: return "Hôm nay"
        case .thisWeek: return "Tuần này"
        case .thisMonth: return "Tháng này"
        case .custom: return "Tùy chỉnh"
        }
    }
}

// MARK: - Financial Report Service

class FinancialReportService {
    static let shared = FinancialReportService()
    
    private init() {}
    
    // Aggregate data into daily stats
    func generateReport(orders: [Bill], expenses: [OperatingExpense], restocks: [RestockBill], range: ReportDateRange) -> [DailyFinancialStats] {
        var statsByDate: [Date: DailyFinancialStats] = [:]
        
        let calendar = Calendar.current
        let (startDate, endDate) = getDateRange(range)
        
        // Helper to normalize date to start of day
        func startOfDay(_ date: Date) -> Date {
            return calendar.startOfDay(for: date)
        }
        
        // 1. Process Orders (Revenue & COGS) - only count paid orders
        for order in orders {
            if order.isPaid && order.createdAt >= startDate && order.createdAt <= endDate {
                let dateKey = startOfDay(order.createdAt)
                var stats = statsByDate[dateKey] ?? DailyFinancialStats(date: dateKey)
                
                stats.revenue += order.total
                stats.cogs += order.totalCost
                
                statsByDate[dateKey] = stats
            }
        }
        
        // 2. Process Operating Expenses (OPEX)
        for expense in expenses {
            if expense.createdAt >= startDate && expense.createdAt <= endDate {
                let dateKey = startOfDay(expense.createdAt)
                var stats = statsByDate[dateKey] ?? DailyFinancialStats(date: dateKey)
                
                stats.operatingCosts += expense.amount
                
                statsByDate[dateKey] = stats
            }
        }
        
        // 3. Process Restocks (Incurred Fees)
        for restock in restocks {
            if restock.createdAt >= startDate && restock.createdAt <= endDate {
                let dateKey = startOfDay(restock.createdAt)
                var stats = statsByDate[dateKey] ?? DailyFinancialStats(date: dateKey)
                
                // Only "Additional Cost" (Incurred Fees) affects daily profit immediately
                // The "Unit Price" (Import Price) goes to Inventory Value -> COGS when sold
                let totalAdditionalCost = restock.items.reduce(0) { $0 + $1.additionalCost }
                stats.incurredFees += totalAdditionalCost
                
                statsByDate[dateKey] = stats
            }
        }
        
        // Convert to sorted array
        return statsByDate.values.sorted { $0.date > $1.date }
    }
    
    // Generate CSV File — bao gồm bán lẻ, bán sỉ và tổng hợp
    func exportToCSV(stats: [DailyFinancialStats], wholesale: OrderViewModel.WholesaleStats? = nil) -> URL? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd-MM-yyyy"  // Dùng dấu gạch ngang, tránh "/" trong tên file

        let fileName = "BaoCaoTaiChinh_\(df.string(from: Date())).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var csv = ""

        // ── PHẦN 1: BÁN LẺ (POS) ──────────────────────────────────────
        csv += "=== BÁN LẺ (POS) ===\n"
        csv += "Ngày,Doanh thu,Giá vốn (COGS),Chi phí vận hành,Lợi nhuận ròng,Tỷ suất (%)\n"

        let sortedStats = stats.sorted { $0.date < $1.date }
        for s in sortedStats {
            csv += "\(df.string(from: s.date)),\(fmt(s.revenue)),\(fmt(s.cogs)),\(fmt(s.operatingCosts)),\(fmt(s.netProfit)),\(String(format: "%.1f", s.profitMargin))%\n"
        }

        let totalRevenue = stats.reduce(0) { $0 + $1.revenue }
        let totalCOGS    = stats.reduce(0) { $0 + $1.cogs }
        let totalOpEx    = stats.reduce(0) { $0 + $1.operatingCosts }
        let totalNet     = stats.reduce(0) { $0 + $1.netProfit }
        let totalMargin  = totalRevenue > 0 ? (totalNet / totalRevenue) * 100 : 0
        csv += "TỔNG BÁN LẺ,\(fmt(totalRevenue)),\(fmt(totalCOGS)),\(fmt(totalOpEx)),\(fmt(totalNet)),\(String(format: "%.1f", totalMargin))%\n"
        csv += "\n"

        // ── PHẦN 2: BÁN SỈ / SẢN XUẤT ────────────────────────────────
        if let ws = wholesale {
            csv += "=== BÁN SỈ / SẢN XUẤT ===\n"
            csv += "Ngày,Khách hàng,SĐT,Doanh thu sỉ,Đã thu,Còn nợ,Sản phẩm\n"

            let txSorted = ws.transactions.sorted { $0.createdAt < $1.createdAt }
            for tx in txSorted {
                let items = tx.items.prefix(3).map { $0.name }.joined(separator: " / ")
                csv += "\(df.string(from: tx.createdAt)),\(tx.buyerName ?? ""),\(tx.buyerPhone ?? ""),\(fmt(tx.grandTotal ?? 0)),\(fmt(tx.paidAmount ?? 0)),\(fmt(tx.debtAmount ?? 0)),\(items)\n"
            }

            let wsNetProfit = ws.paid - ws.materialCost
            let wsDashboardProfit = ws.revenue - ws.materialExportCost
            let inventoryValue = ws.materialCost - ws.materialExportCost
            csv += "\n"
            csv += "Tổng doanh thu sỉ,\(fmt(ws.revenue))\n"
            csv += "Tổng đã thu,\(fmt(ws.paid))\n"
            csv += "Tổng còn nợ,\(fmt(ws.debt))\n"
            csv += "Chi phí nguyên liệu (nhập),\(fmt(ws.materialCost))\n"
            csv += "Giá trị nguyên liệu đã xuất,\(fmt(ws.materialExportCost))\n"
            csv += "Lợi nhuận ròng bán sỉ (đã thu - chi phí NL),\(fmt(wsNetProfit))\n"
            csv += "Lợi nhuận (giống Tổng quan - doanh thu sỉ - giá trị xuất NL),\(fmt(wsDashboardProfit))\n"
            csv += "Tổng giá trị tồn kho nguyên liệu (nhập - xuất),\(fmt(inventoryValue))\n"
            csv += "\n"

            // ── PHẦN 3: TỔNG HỢP ──────────────────────────────────────
            let combined = totalNet + wsNetProfit
            csv += "=== TỔNG HỢP ===\n"
            csv += "Lợi nhuận bán lẻ,\(fmt(totalNet))\n"
            csv += "Lợi nhuận bán sỉ,\(fmt(wsNetProfit))\n"
            csv += "TỔNG LỢI NHUẬN RÒNG,\(fmt(combined))\n"
        }

        do {
            // Thêm BOM UTF-8 để Excel đọc đúng tiếng Việt
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(csv.data(using: .utf8) ?? Data())
            try data.write(to: path)
            print("✅ [Export] CSV ghi thành công: \(path.path), size: \(data.count) bytes")
            return path
        } catch {
            print("❌ [Export] Lỗi ghi CSV: \(error)")
            return nil
        }
    }

    private func fmt(_ value: Double) -> String {
        let n = NSNumber(value: value)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.maximumFractionDigits = 0
        return f.string(from: n) ?? "\(Int(value))"
    }

    // Legacy — giữ lại để tương thích
    func exportToCSV(stats: [DailyFinancialStats]) -> URL? {
        exportToCSV(stats: stats, wholesale: nil)
    }
    
    private func getDateRange(_ range: ReportDateRange) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch range {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            return (start, end)
            
        case .thisWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? now
            return (start, end)
            
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now
            return (start, end)
            
        case .custom(let start, let end):
            return (start, end)
        }
    }
}
