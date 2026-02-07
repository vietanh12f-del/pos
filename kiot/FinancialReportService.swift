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
        grossProfit - (operatingCosts + incurredFees)
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
        
        // 1. Process Orders (Revenue & COGS)
        for order in orders {
            if order.createdAt >= startDate && order.createdAt <= endDate {
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
    
    // Generate CSV File
    func exportToCSV(stats: [DailyFinancialStats]) -> URL? {
        let fileName = "Financial_Report_\(Date().timeIntervalSince1970).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var csvText = "Ngày,Doanh thu,Giá vốn (COGS),Chi phí vận hành,Chi phí phát sinh,Lợi nhuận ròng,Tỷ suất (%)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        for stat in stats {
            let line = "\(dateFormatter.string(from: stat.date)),\(stat.revenue),\(stat.cogs),\(stat.operatingCosts),\(stat.incurredFees),\(stat.netProfit),\(String(format: "%.2f", stat.profitMargin))%\n"
            csvText.append(line)
        }
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
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
