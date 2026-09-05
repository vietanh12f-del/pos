import Foundation
import SwiftUI
import UIKit

// Import các manager classes
// Lưu ý: Các classes này phải được định nghĩa trong cùng module hoặc được import

// MARK: - Financial Data Models

struct DailyFinancialStats: Identifiable, Codable {
    var id: Date { date }
    let date: Date
    var revenue: Double = 0 // Tổng doanh thu (bao gồm cả công nợ)
    var actualReceived: Double = 0 // Thực thu (đã nhận được)
    var debt: Double = 0 // Công nợ
    var cogs: Double = 0
    var operatingCosts: Double = 0
    var incurredFees: Double = 0
    
    var grossProfit: Double {
        revenue - cogs
    }
    
    var netProfit: Double {
        grossProfit - operatingCosts // - incurredFees (Removed as requested)
    }
    
    var actualNetProfit: Double {
        actualReceived - cogs - operatingCosts // Lợi nhuận dựa trên thực thu
    }
    
    var profitMargin: Double {
        guard revenue > 0 else { return 0 }
        return (netProfit / revenue) * 100
    }
    
    var actualProfitMargin: Double {
        guard actualReceived > 0 else { return 0 }
        return (actualNetProfit / actualReceived) * 100
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
        
        // 1. Process Orders (Revenue, Actual Received, Debt & COGS) - include ALL non-deleted orders
        for order in orders {
            if !order.isDeleted && order.createdAt >= startDate && order.createdAt <= endDate {
                let dateKey = startOfDay(order.createdAt)
                var stats = statsByDate[dateKey] ?? DailyFinancialStats(date: dateKey)
                
                stats.revenue += order.total
                stats.cogs += order.totalCost
                
                // Tính thực thu và công nợ (bao gồm cả đơn chưa thanh toán)
                if order.isPaid {
                    stats.actualReceived += (order.paidAmount ?? order.total)
                } else {
                    stats.actualReceived += (order.paidAmount ?? 0)
                }
                
                stats.debt += order.effectiveDebt
                
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
    
    // Generate Comprehensive Image Report - Enhanced Version
    func exportToImage(stats: [DailyFinancialStats], wholesale: OrderViewModel.WholesaleStats? = nil, orders: [Bill] = [], products: [Product] = []) -> URL? {
        
        let fileName = "BaoCaoTaiChinh_\(Int(Date().timeIntervalSince1970)).png"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Check if production feature is enabled
        let productionEnabled = StoreManager.shared.currentStoreProductionEnabled()
        
        // Calculate dynamic page height based on content
        let debtOrders = orders.filter { $0.effectiveDebt > 0 }
        let customerCount = Set(debtOrders.compactMap { $0.customerName }).count
        
        // Base content height estimation
        let baseHeight: CGFloat = 1200
        let orderTableHeight: CGFloat = CGFloat(min(orders.count, 15)) * 20 + 100
        let inventoryHeight: CGFloat = CGFloat(min(products.count, 20)) * 20 + 150
        let debtTableHeight: CGFloat = CGFloat(customerCount) * 20 + 100
        let productionHeight: CGFloat = productionEnabled ? 400 : 0
        
        let totalEstimatedHeight = baseHeight + orderTableHeight + inventoryHeight + debtTableHeight + productionHeight
        
        // Use multiple pages if content is too long
        let _: CGFloat = 2000 // Will be used for multi-page in future
        let pageWidth: CGFloat = 850
        
        // Use dynamic page height without multi-page for now
        let pageSize = CGSize(width: pageWidth, height: min(totalEstimatedHeight + 500, 3000))
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: pageSize))
            
            var currentY: CGFloat = 40
            let margin: CGFloat = 40
            let contentWidth = pageSize.width - (margin * 2)
            
            // MARK: - Title and Header
            let titleText = "BÁO CÁO ĐỐI SOÁT TÀI CHÍNH"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.black
            ]
            let titleSize = titleText.size(withAttributes: titleAttributes)
            titleText.draw(at: CGPoint(x: (pageSize.width - titleSize.width) / 2, y: currentY), withAttributes: titleAttributes)
            currentY += 50
            
            // Store and Date Information
            let headerFont = UIFont.systemFont(ofSize: 14)
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.darkGray
            ]
            
            let store = StoreManager.shared.currentStore
            let user = AuthManager.shared.currentUserProfile
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "vi_VN")
            dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
            
            let headerInfo = [
                "Cửa hàng: \(store?.name ?? "SmartKiot")",
                "Địa chỉ: \(store?.address ?? "Chưa cập nhật")",
                "Thời gian xuất: \(dateFormatter.string(from: Date()))",
                "Người lập: \(user?.fullName ?? "Nhân viên")",
                "Khoảng thời gian: \(getDateRangeString(stats))"
            ]
            
            for info in headerInfo {
                info.draw(at: CGPoint(x: margin, y: currentY), withAttributes: headerAttributes)
                currentY += 22
            }
            
            currentY += 20
            
            // MARK: - Summary Section (Kết quả đối soát và số tiền tất toán)
            drawSectionTitle("KẾT QUẢ ĐỐI SOÁT VÀ SỐ TIỀN TẤT TOÁN", at: &currentY, pageWidth: pageSize.width, margin: margin)
            
            let summaryData = calculateSummaryData(stats: stats, wholesale: wholesale, orders: orders, products: products, productionEnabled: productionEnabled)
            drawSummaryTable(summaryData, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth, productionEnabled: productionEnabled)
            
            currentY += 30
            
            // MARK: - Order List
            let retailOrders = getRetailOrdersInRange(orders, stats: stats)
            drawSectionTitle("CHI TIẾT CÁC ĐơN HÀNG", at: &currentY, pageWidth: pageSize.width, margin: margin)
            drawOrderList(orders: retailOrders, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth)
            
            currentY += 30
            
            // MARK: - Debt Details (if any) - Moved up to be right after order list
            let debtOrders = orders.filter { $0.effectiveDebt > 0 }
            if !debtOrders.isEmpty {
                drawSectionTitle("CHI TIẾT CÔNG NỢ THEO KHÁCH HÀNG", at: &currentY, pageWidth: pageSize.width, margin: margin)
                drawDebtDetailsTable(orders: debtOrders, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth)
                currentY += 30
            }
            
            // MARK: - Top Selling Products
            let topProducts = getTopSellingProducts(orders: retailOrders, limit: 5)
            if !topProducts.isEmpty {
                drawSectionTitle("SẢN PHẨM BÁN CHẠY", at: &currentY, pageWidth: pageSize.width, margin: margin)
                drawTopProducts(topProducts, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth)
                currentY += 30
            }
            
            // MARK: - Wholesale Section (only if production enabled)
            if productionEnabled, let ws = wholesale {
                drawSectionTitle("BÁO CÁO BÁN SỈ / SẢN XUẤT", at: &currentY, pageWidth: pageSize.width, margin: margin)
                drawWholesaleSection(ws, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth)
                currentY += 30
            }
            
            // MARK: - Inventory Summary
            drawSectionTitle("TÓM TẮT TỒN KHO", at: &currentY, pageWidth: pageSize.width, margin: margin)
            drawInventorySummary(products: products, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth)
            
            currentY += 30

            
            // MARK: - Detailed Inventory List
            drawSectionTitle("CHI TIẾT TỒN KHO", at: &currentY, pageWidth: pageSize.width, margin: margin)
            drawDetailedInventory(products: products, context: cgContext, startY: &currentY, margin: margin, contentWidth: contentWidth)
            
            currentY += 40
            
            // MARK: - Footer
            let footerText = "Báo cáo được tạo tự động bởi SmartKiot POS System"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let footerSize = footerText.size(withAttributes: footerAttributes)
            footerText.draw(at: CGPoint(x: (pageSize.width - footerSize.width) / 2, y: pageSize.height - 60), withAttributes: footerAttributes)
        }
        
        do {
            if let imageData = image.pngData() {
                try imageData.write(to: path)
                print("✅ Enhanced image report saved: \(path.path)")
                return path
            }
        } catch {
            print("❌ Export error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Helper Functions for Enhanced Image Export
    
    private func drawSectionTitle(_ title: String, at currentY: inout CGFloat, pageWidth: CGFloat, margin: CGFloat) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
        currentY += 35
    }
    
    private struct SummaryData {
        let retailRevenue: Double
        let retailCosts: Double  
        let retailProfit: Double
        let retailActualReceived: Double
        let retailDebt: Double
        let wholesaleRevenue: Double
        let wholesaleCosts: Double
        let wholesaleProfit: Double
        let totalRevenue: Double
        let totalCosts: Double
        let totalProfit: Double
        let inventoryValue: Double
        let orderCount: Int
        let customerCount: Int
    }
    
    private func calculateSummaryData(stats: [DailyFinancialStats], wholesale: OrderViewModel.WholesaleStats?, orders: [Bill], products: [Product], productionEnabled: Bool) -> SummaryData {
        let retailRevenue = stats.reduce(0) { $0 + $1.revenue }
        let retailCosts = stats.reduce(0) { $0 + $1.cogs + $1.operatingCosts }
        let retailProfit = stats.reduce(0) { $0 + $1.actualNetProfit }
        let retailActualReceived = stats.reduce(0) { $0 + $1.actualReceived }
        let retailDebt = stats.reduce(0) { $0 + $1.debt }
        
        var wholesaleRevenue: Double = 0
        var wholesaleCosts: Double = 0
        var wholesaleProfit: Double = 0
        
        if productionEnabled, let ws = wholesale {
            wholesaleRevenue = ws.revenue
            wholesaleCosts = ws.materialExportCost
            wholesaleProfit = ws.revenue - ws.materialExportCost
        }
        
        let totalRevenue = retailRevenue + wholesaleRevenue
        let totalCosts = retailCosts + wholesaleCosts
        let totalProfit = retailProfit + wholesaleProfit
        
        let inventoryValue = products.reduce(0) { $0 + (Double($1.stockQuantity) * $1.costPrice) }
        
        let retailOrders = getRetailOrdersInRange(orders, stats: stats)
        let orderCount = retailOrders.count
        let customerCount = getUniqueCustomerCount(orders: retailOrders)
        
        return SummaryData(
            retailRevenue: retailRevenue,
            retailCosts: retailCosts,
            retailProfit: retailProfit,
            retailActualReceived: retailActualReceived,
            retailDebt: retailDebt,
            wholesaleRevenue: wholesaleRevenue,
            wholesaleCosts: wholesaleCosts,
            wholesaleProfit: wholesaleProfit,
            totalRevenue: totalRevenue,
            totalCosts: totalCosts,
            totalProfit: totalProfit,
            inventoryValue: inventoryValue,
            orderCount: orderCount,
            customerCount: customerCount
        )
    }
    
    private func drawSummaryTable(_ data: SummaryData, context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat, productionEnabled: Bool) {
        let rowHeight: CGFloat = 25
        let labelWidth: CGFloat = contentWidth * 0.6
        let valueWidth: CGFloat = contentWidth * 0.4
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        var summaryRows: [(String, String, Bool)] = [
            ("I. DOANH THU BÁN LẺ", fmt(data.retailRevenue), false),
            ("   - Thực thu", fmt(data.retailActualReceived), false),
            ("   - Công nợ", fmt(data.retailDebt), false),
            ("   - Chi phí bán lẻ", fmt(data.retailCosts), false),
            ("   - Lợi nhuận bán lẻ", fmt(data.retailProfit), false),
        ]
        
        // Only add wholesale section if production is enabled
        if productionEnabled {
            summaryRows.append(contentsOf: [
                ("", "", false),
                ("II. DOANH THU BÁN SỈ", fmt(data.wholesaleRevenue), false),
                ("   - Chi phí sản xuất", fmt(data.wholesaleCosts), false),
                ("   - Lợi nhuận bán sỉ", fmt(data.wholesaleProfit), false),
            ])
        }
        
        summaryRows.append(contentsOf: [
            ("", "", false),
            ("III. TỔNG KẾT", "", true),
            ("   - Tổng doanh thu", fmt(data.totalRevenue), true),
            ("   - Tổng chi phí", fmt(data.totalCosts), false),
            ("   - Lợi nhuận ròng", fmt(data.totalProfit), true),
            ("", "", false),
            ("IV. THỐNG KÊ KHÁC", "", false),
            ("   - Số đơn hàng", "\(data.orderCount)", false),
            ("   - Số khách hàng", "\(data.customerCount)", false),
            ("   - Giá trị tồn kho", fmt(data.inventoryValue), false)
        ])
        
        for (label, value, isBold) in summaryRows {
            if !label.isEmpty || !value.isEmpty {
                // Draw background for header rows
                if isBold {
                    context.setFillColor(UIColor.systemGray6.cgColor)
                    context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
                }
                
                // Draw border
                context.setStrokeColor(UIColor.lightGray.cgColor)
                context.setLineWidth(0.5)
                context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
                
                let attributes = isBold ? boldAttributes : cellAttributes
                
                label.draw(in: CGRect(x: margin + 10, y: startY + 5, width: labelWidth - 20, height: rowHeight - 10), withAttributes: attributes)
                value.draw(in: CGRect(x: margin + labelWidth + 10, y: startY + 5, width: valueWidth - 20, height: rowHeight - 10), withAttributes: attributes)
            }
            
            startY += rowHeight
        }
    }
    
    private func drawOrderList(orders: [Bill], context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        guard !orders.isEmpty else {
            let noDataText = "Không có đơn hàng trong khoảng thời gian này"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 13),
                .foregroundColor: UIColor.gray
            ]
            noDataText.draw(at: CGPoint(x: margin, y: startY), withAttributes: attributes)
            startY += 25
            return
        }
        
        let rowHeight: CGFloat = 20
        let columnWidths: [CGFloat] = [
            contentWidth * 0.05, // STT
            contentWidth * 0.10, // Mã đơn
            contentWidth * 0.10, // Nhân viên
            contentWidth * 0.20, // Sản phẩm
            contentWidth * 0.07, // Số lượng
            contentWidth * 0.10, // Giá bán
            contentWidth * 0.12, // Thành tiền
            contentWidth * 0.12, // Công nợ
            contentWidth * 0.09, // Thời gian
            contentWidth * 0.05  // Ghi chú
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        
        let headers = ["STT", "Mã đơn", "NV bán", "Sản phẩm", "SL", "Giá bán", "Thành tiền", "Công nợ", "Thời gian", "Ghi chú"]
        
        // Draw header
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        var currentX = margin
        for (index, header) in headers.enumerated() {
            header.draw(in: CGRect(x: currentX + 2, y: startY + 4, width: columnWidths[index] - 4, height: rowHeight - 8), withAttributes: headerAttributes)
            currentX += columnWidths[index]
        }
        
        startY += rowHeight
        
        // Draw data rows (limit to 15 most recent orders for better readability)
        let sortedOrders = orders.sorted { $0.createdAt > $1.createdAt }.prefix(15)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "vi_VN")
        dateFormatter.dateFormat = "dd/MM HH:mm"
        
        var totalQuantity = 0
        var totalAmount = 0.0
        var totalDebt = 0.0
        
        for (index, order) in sortedOrders.enumerated() {
            // Alternate row colors
            if index % 2 == 1 {
                context.setFillColor(UIColor.systemGray6.cgColor)
                context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            }
            
            // Draw border
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(0.3)
            context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            
            // Prepare data
            let orderCode = order.sequenceNumber?.isEmpty == false ? order.sequenceNumber! : "---"
            let employee = order.creatorName?.isEmpty == false ? order.creatorName! : "---"
            let productNames = order.items.prefix(2).map { $0.name }.joined(separator: ", ")
            let products = order.items.count > 2 ? productNames + "..." : productNames
            let orderQuantity = order.items.reduce(0) { $0 + $1.quantity }
            let unitPrice = order.items.count == 1 ? fmt(order.items[0].price) : "Nhiều"
            let totalPrice = fmt(order.total)
            let debtAmount = fmt(order.effectiveDebt)
            let timeString = dateFormatter.string(from: order.createdAt)
            let note = "" // Leave empty as requested
            
            // Add to totals
            totalQuantity += orderQuantity
            totalAmount += order.total
            totalDebt += order.effectiveDebt
            
            let rowData = [
                "\(index + 1)",
                orderCode,
                employee,
                products,
                "\(orderQuantity)",
                unitPrice,
                totalPrice,
                debtAmount,
                timeString,
                note
            ]
            
            currentX = margin
            for (colIndex, data) in rowData.enumerated() {
                data.draw(in: CGRect(x: currentX + 2, y: startY + 2, width: columnWidths[colIndex] - 4, height: rowHeight - 4), withAttributes: cellAttributes)
                currentX += columnWidths[colIndex]
            }
            
            startY += rowHeight
        }
        
        // Add summary info if there are more orders
        if orders.count > 15 {
            let moreOrdersText = "... và \(orders.count - 15) đơn hàng khác"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            moreOrdersText.draw(at: CGPoint(x: margin, y: startY + 5), withAttributes: attributes)
            startY += 20
        }
        
        // Draw total row
        context.setFillColor(UIColor.systemGray5.cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        
        let totalRowData = [
            "",
            "",
            "",
            "TỔNG CỘNG",
            "\(totalQuantity)",
            "",
            fmt(totalAmount),
            fmt(totalDebt),
            "",
            ""
        ]
        
        currentX = margin
        for (colIndex, data) in totalRowData.enumerated() {
            data.draw(in: CGRect(x: currentX + 2, y: startY + 2, width: columnWidths[colIndex] - 4, height: rowHeight - 4), withAttributes: boldAttributes)
            currentX += columnWidths[colIndex]
        }
        
        startY += rowHeight
    }
    
    private func drawTopProducts(_ products: [TopSellingProduct], context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        let rowHeight: CGFloat = 22
        let columnWidths: [CGFloat] = [
            contentWidth * 0.1,  // STT
            contentWidth * 0.5,  // Product name
            contentWidth * 0.2,  // Quantity
            contentWidth * 0.2   // Revenue
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let headers = ["STT", "Sản phẩm", "Số lượng", "Doanh thu"]
        
        // Draw header
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        var currentX = margin
        for (index, header) in headers.enumerated() {
            header.draw(in: CGRect(x: currentX + 5, y: startY + 5, width: columnWidths[index] - 10, height: rowHeight - 10), withAttributes: headerAttributes)
            currentX += columnWidths[index]
        }
        
        startY += rowHeight
        
        for (index, product) in products.prefix(5).enumerated() {
            // Alternate row colors
            if index % 2 == 1 {
                context.setFillColor(UIColor.systemGray6.cgColor)
                context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            }
            
            // Draw border
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(0.3)
            context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            
            let productName = product.name.count > 25 ? String(product.name.prefix(22)) + "..." : product.name
            let rowData = [
                "\(index + 1)",
                productName,
                "\(product.quantity)",
                fmt(product.revenue)
            ]
            
            currentX = margin
            for (colIndex, data) in rowData.enumerated() {
                data.draw(in: CGRect(x: currentX + 5, y: startY + 3, width: columnWidths[colIndex] - 10, height: rowHeight - 6), withAttributes: cellAttributes)
                currentX += columnWidths[colIndex]
            }
            
            startY += rowHeight
        }
    }
    
    private func drawWholesaleSection(_ wholesale: OrderViewModel.WholesaleStats, context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        
        let wsStats = [
            "Tổng doanh thu bán sỉ: \(fmt(wholesale.revenue))",
            "Đã thu tiền: \(fmt(wholesale.paid))",
            "Còn công nợ: \(fmt(wholesale.debt))",
            "Chi phí nguyên liệu: \(fmt(wholesale.materialExportCost))",
            "Lợi nhuận bán sỉ: \(fmt(wholesale.revenue - wholesale.materialExportCost))"
        ]
        
        for stat in wsStats {
            stat.draw(at: CGPoint(x: margin, y: startY), withAttributes: cellAttributes)
            startY += 22
        }
    }
    
    private func drawInventorySummary(products: [Product], context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        let inventoryStats = getInventoryStats(products: products)
        let totalValue = inventoryStats.reduce(0) { $0 + $1.totalValue }
        let totalItems = inventoryStats.count
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        
        let inventoryInfo = [
            "Tổng số mặt hàng tồn kho: \(totalItems)",
            "Tổng giá trị tồn kho: \(fmt(totalValue))",
            "Giá trị trung bình/sản phẩm: \(fmt(totalItems > 0 ? totalValue / Double(totalItems) : 0))"
        ]
        
        for info in inventoryInfo {
            info.draw(at: CGPoint(x: margin, y: startY), withAttributes: cellAttributes)
            startY += 22
        }
    }
    
    private func drawDetailedInventory(products: [Product], context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        let inventoryStats = getInventoryStats(products: products)
        
        guard !inventoryStats.isEmpty else {
            let noDataText = "Không có sản phẩm tồn kho"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 13),
                .foregroundColor: UIColor.gray
            ]
            noDataText.draw(at: CGPoint(x: margin, y: startY), withAttributes: attributes)
            startY += 25
            return
        }
        
        let rowHeight: CGFloat = 20
        let columnWidths: [CGFloat] = [
            contentWidth * 0.08, // STT
            contentWidth * 0.35, // Tên sản phẩm
            contentWidth * 0.12, // Tồn kho
            contentWidth * 0.15, // Giá vốn
            contentWidth * 0.15, // Tổng giá trị
            contentWidth * 0.15  // Danh mục
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        let headers = ["STT", "Sản phẩm", "Tồn kho", "Giá vốn", "Tổng giá trị", "Danh mục"]
        
        // Draw header
        context.setFillColor(UIColor.systemGreen.cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        var currentX = margin
        for (index, header) in headers.enumerated() {
            header.draw(in: CGRect(x: currentX + 2, y: startY + 4, width: columnWidths[index] - 4, height: rowHeight - 8), withAttributes: headerAttributes)
            currentX += columnWidths[index]
        }
        
        startY += rowHeight
        
        // Draw data rows (limit to 15 items for readability)
        let sortedInventory = inventoryStats.prefix(15)
        
        for (index, item) in sortedInventory.enumerated() {
            // Alternate row colors
            if index % 2 == 1 {
                context.setFillColor(UIColor.systemGray6.cgColor)
                context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            }
            
            // Draw border
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(0.3)
            context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            
            // Prepare data
            let productName = item.name.count > 20 ? String(item.name.prefix(17)) + "..." : item.name
            let category = item.category.count > 10 ? String(item.category.prefix(7)) + "..." : item.category
            
            let rowData = [
                "\(index + 1)",
                productName,
                "\(item.stockQuantity)",
                fmt(item.costPrice),
                fmt(item.totalValue),
                category
            ]
            
            currentX = margin
            for (colIndex, data) in rowData.enumerated() {
                data.draw(in: CGRect(x: currentX + 2, y: startY + 2, width: columnWidths[colIndex] - 4, height: rowHeight - 4), withAttributes: cellAttributes)
                currentX += columnWidths[colIndex]
            }
            
            startY += rowHeight
        }
        
        // Add summary info if there are more items
        if inventoryStats.count > 15 {
            let moreItemsText = "... và \(inventoryStats.count - 15) sản phẩm khác"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 11),
                .foregroundColor: UIColor.gray
            ]
            moreItemsText.draw(at: CGPoint(x: margin, y: startY + 5), withAttributes: attributes)
            startY += 25
        }
        
        // Total row
        context.setFillColor(UIColor.systemGray5.cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        let totalValue = inventoryStats.reduce(0) { $0 + $1.totalValue }
        let totalQty = inventoryStats.reduce(0) { $0 + $1.stockQuantity }
        
        let totalRowData = [
            "",
            "TỔNG CỘNG",
            "\(totalQty)",
            "",
            fmt(totalValue),
            ""
        ]
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        currentX = margin
        for (colIndex, data) in totalRowData.enumerated() {
            data.draw(in: CGRect(x: currentX + 2, y: startY + 2, width: columnWidths[colIndex] - 4, height: rowHeight - 4), withAttributes: boldAttributes)
            currentX += columnWidths[colIndex]
        }
        
        startY += rowHeight
    }
    
    func exportToCSV(stats: [DailyFinancialStats], wholesale: OrderViewModel.WholesaleStats? = nil, orders: [Bill] = [], products: [Product] = []) -> URL? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd-MM-yyyy"  // Dùng dấu gạch ngang, tránh "/" trong tên file

        let fileName = "BaoCaoTaiChinh_\(df.string(from: Date())).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Check if production feature is enabled
        let productionEnabled = StoreManager.shared.currentStoreProductionEnabled()

        var csv = ""

        // ── HEADER THÔNG TIN ────────────────────────────────────────
        let store = StoreManager.shared.currentStore
        let user = AuthManager.shared.currentUserProfile
        let now = Date()
        let headerFormatter = DateFormatter()
        headerFormatter.locale = Locale(identifier: "vi_VN")
        headerFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        // Header with simple format
        csv += "=== BÁO CÁO TÀI CHÍNH ===\n"
        csv += "Cửa hàng: \(store?.name ?? "SmartKiot")\n"
        if let address = store?.address, !address.isEmpty {
            csv += "Địa chỉ: \(address)\n"
        }
        csv += "Thời gian xuất: \(headerFormatter.string(from: now))\n"
        csv += "Người xuất: \(user?.fullName ?? "Nhân viên")\n"
        csv += "Khoảng thời gian: \(getDateRangeString(stats))\n"
        if productionEnabled {
            csv += "Chế độ: Bán lẻ + Sản xuất\n"
        } else {
            csv += "Chế độ: Chỉ bán lẻ\n"
        }
        csv += "=====================================\n"
        csv += "\n"

        // ── TỔNG QUAN ──────────────────────────────────────────────
        csv += "=== TỔNG QUAN ===\n"
        let retailOrders = getRetailOrdersInRange(orders, stats: stats)
        let uniqueCustomers = getUniqueCustomerCount(orders: retailOrders)
        let avgOrderValue = retailOrders.isEmpty ? 0 : retailOrders.reduce(0) { $0 + $1.total } / Double(retailOrders.count)
        let totalVATCollected = getTotalVATCollected(orders: retailOrders)
        
        csv += "Tổng số đơn bán lẻ,\(retailOrders.count)\n"
        if productionEnabled {
            csv += "Tổng số đơn bán sỉ,\(wholesale?.transactions.count ?? 0)\n"
        }
        csv += "Số khách hàng unique,\(uniqueCustomers)\n"
        csv += "Đơn hàng trung bình,\(fmt(avgOrderValue))\n"
        csv += "Tổng VAT đã thu,\(fmt(totalVATCollected))\n"
        csv += "=====================================\n"
        csv += "\n"

        // ── SẢN PHẨM BÁN CHẠY ──────────────────────────────────────
        let topProducts = getTopSellingProducts(orders: retailOrders, limit: 10)
        if !topProducts.isEmpty {
            csv += "=== SẢN PHẨM BÁN CHẠY (TOP 10) ===\n"
            csv += "STT,Sản phẩm,Số lượng,Doanh thu,% Tổng\n"
            let totalRevenue = topProducts.reduce(0) { $0 + $1.revenue }
            for (index, product) in topProducts.enumerated() {
                let percentage = totalRevenue > 0 ? (product.revenue / totalRevenue) * 100 : 0
                csv += "\(index + 1),\(product.name),\(product.quantity),\(fmt(product.revenue)),\(String(format: "%.1f", percentage))%\n"
            }
            csv += "=====================================\n"
            csv += "\n"
        }

        // ── PHẦN 1: BÁN LẺ (POS) ──────────────────────────────────────
        csv += "=== BÁN LẺ (POS) ===\n"
        csv += "Ngày,Doanh thu,Giá vốn,Chi phí VH,Lợi nhuận,Tỷ suất %\n"

        let sortedStats = stats.sorted { $0.date < $1.date }
        for s in sortedStats {
            csv += "\(df.string(from: s.date)),\(fmt(s.revenue)),\(fmt(s.cogs)),\(fmt(s.operatingCosts)),\(fmt(s.netProfit)),\(String(format: "%.1f", s.profitMargin))\n"
        }

        let totalRevenue = stats.reduce(0) { $0 + $1.revenue }
        let totalCOGS    = stats.reduce(0) { $0 + $1.cogs }
        let totalOpEx    = stats.reduce(0) { $0 + $1.operatingCosts }
        let totalNet     = stats.reduce(0) { $0 + $1.netProfit }
        let totalMargin  = totalRevenue > 0 ? (totalNet / totalRevenue) * 100 : 0
        csv += "TỔNG BÁN LẺ,\(fmt(totalRevenue)),\(fmt(totalCOGS)),\(fmt(totalOpEx)),\(fmt(totalNet)),\(String(format: "%.1f", totalMargin))\n"
        csv += "=====================================\n"
        csv += "\n"

        // ── PHẦN 2: BÁN SỈ / SẢN XUẤT ────────────────────────────────
        // Chỉ hiển thị nếu tính năng sản xuất được bật
        if productionEnabled, let ws = wholesale {
            csv += "=== BÁN SỈ / SẢN XUẤT ===\n"
            csv += "Ngày,Khách hàng,SĐT,Doanh thu,Đã thu,Còn nợ,Sản phẩm\n"

            let txSorted = ws.transactions.sorted { $0.createdAt < $1.createdAt }
            for tx in txSorted {
                let items = tx.items.prefix(3).map { $0.name }.joined(separator: " / ")
                csv += "\(df.string(from: tx.createdAt)),\(tx.buyerName ?? ""),\(tx.buyerPhone ?? ""),\(fmt(tx.grandTotal ?? 0)),\(fmt(tx.paidAmount ?? 0)),\(fmt(tx.effectiveDebt)),\(items)\n"
            }

            let wsNetProfit = ws.paid - ws.materialCost
            let wsDashboardProfit = ws.revenue - ws.materialExportCost
            let inventoryValue = ws.materialCost - ws.materialExportCost
            csv += "\n"
            csv += "Tổng doanh thu sỉ,\(fmt(ws.revenue))\n"
            csv += "Tổng đã thu,\(fmt(ws.paid))\n"
            csv += "Tổng còn nợ,\(fmt(ws.debt))\n"
            csv += "Chi phí nguyên liệu,\(fmt(ws.materialCost))\n"
            csv += "Giá trị NL đã xuất,\(fmt(ws.materialExportCost))\n"
            csv += "Lợi nhuận ròng bán sỉ,\(fmt(wsNetProfit))\n"
            csv += "Lợi nhuận (giống Tổng quan),\(fmt(wsDashboardProfit))\n"
            csv += "Tổng giá trị tồn kho NL,\(fmt(inventoryValue))\n"
            csv += "=====================================\n"
            csv += "\n"

            // ── PHÂN TÍCH KHÁCH HÀNG SỈ ─────────────────────────────
            let customerAnalysis = analyzeWholesaleCustomers(transactions: ws.transactions)
            if !customerAnalysis.isEmpty {
                csv += "=== PHÂN TÍCH KHÁCH HÀNG SỈ ===\n"
                csv += "STT,Khách hàng,SĐT,Tổng mua,Đã trả,Còn nợ,Số đơn,Lần cuối\n"
                for (index, customer) in customerAnalysis.enumerated() {
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "vi_VN")
                    df.dateFormat = "dd/MM/yyyy"
                    let lastOrderDate = df.string(from: customer.lastOrderDate)
                    csv += "\(index + 1),\(customer.name),\(customer.phone),\(fmt(customer.totalRevenue)),\(fmt(customer.totalPaid)),\(fmt(customer.totalDebt)),\(customer.orderCount),\(lastOrderDate)\n"
                }
                csv += "=====================================\n"
                csv += "\n"
            }

            // ── TỒN KHO VÀ TỔNG HỢP ──────────────────────────────────────
            let combined = totalNet + wsNetProfit
            csv += "=== THỐNG KÊ TỒN KHO ===\n"
            let inventoryStats = getInventoryStats(products: products)
            if !inventoryStats.isEmpty {
                csv += "STT,Sản phẩm,Tồn kho,Giá vốn,Tổng giá trị,Loại\n"
                for (index, item) in inventoryStats.enumerated() {
                    csv += "\(index + 1),\(item.name),\(item.stockQuantity),\(fmt(item.costPrice)),\(fmt(item.totalValue)),\(item.category)\n"
                }
                let totalInventoryValue = inventoryStats.reduce(0) { $0 + $1.totalValue }
                csv += "TỔNG GIÁ TRỊ TỒN KHO,,,,,\(fmt(totalInventoryValue))\n"
            } else {
                csv += "Không có sản phẩm tồn kho\n"
            }
            csv += "=====================================\n"
            csv += "\n"
            
            csv += "=== TỔNG HỢP ===\n"
            csv += "Lợi nhuận bán lẻ,\(fmt(totalNet))\n"
            csv += "Lợi nhuận bán sỉ,\(fmt(wsNetProfit))\n"
            csv += "TỔNG LỢI NHUẬN RÒNG,\(fmt(combined))\n"
            csv += "=====================================\n"
            csv += "\n"
            
            // ── PHÂN TÍCH VAT ──────────────────────────────────────────
            csv += "=== PHÂN TÍCH VAT ===\n"
            let retailOrders = getRetailOrdersInRange(orders, stats: stats)
            let totalVAT = getTotalVATCollected(orders: retailOrders)
            let totalRevenueExVAT = retailOrders.reduce(0) { $0 + ($1.total - $1.vatAmount) }
            let estimatedVATPayable = totalVAT * 0.9 // Giả sử VAT đầu ra - VAT đầu vào (ước tính 90%)
            
            csv += "Doanh thu chưa VAT,\(fmt(totalRevenueExVAT))\n"
            csv += "Tổng VAT đã thu,\(fmt(totalVAT))\n"
            csv += "VAT cần nộp (ước tính),\(fmt(estimatedVATPayable))\n"
            csv += "=====================================\n"
        } else {
            // Không có bán sỉ - chỉ có bán lẻ (production tắt hoặc không có dữ liệu)
            csv += "=== THỐNG KÊ TỒN KHO ===\n"
            let inventoryStats = getInventoryStats(products: products)
            if !inventoryStats.isEmpty {
                csv += "STT,Sản phẩm,Tồn kho,Giá vốn,Tổng giá trị,Loại\n"
                for (index, item) in inventoryStats.enumerated() {
                    csv += "\(index + 1),\(item.name),\(item.stockQuantity),\(fmt(item.costPrice)),\(fmt(item.totalValue)),\(item.category)\n"
                }
                let totalInventoryValue = inventoryStats.reduce(0) { $0 + $1.totalValue }
                csv += "TỔNG GIÁ TRỊ TỒN KHO,,,,,\(fmt(totalInventoryValue))\n"
            } else {
                csv += "Không có sản phẩm tồn kho\n"
            }
            csv += "=====================================\n"
            csv += "\n"
            
            csv += "=== TỔNG HỢP ===\n"
            csv += "Lợi nhuận bán lẻ,\(fmt(totalNet))\n"
            csv += "TỔNG LỢI NHUẬN RÒNG,\(fmt(totalNet))\n"
            csv += "=====================================\n"
            csv += "\n"
            
            // ── PHÂN TÍCH VAT ──────────────────────────────────────────
            csv += "=== PHÂN TÍCH VAT ===\n"
            let retailOrders = getRetailOrdersInRange(orders, stats: stats)
            let totalVAT = getTotalVATCollected(orders: retailOrders)
            let totalRevenueExVAT = retailOrders.reduce(0) { $0 + ($1.total - $1.vatAmount) }
            let estimatedVATPayable = totalVAT * 0.9 // Giả sử VAT đầu ra - VAT đầu vào (ước tính 90%)
            
            csv += "Doanh thu chưa VAT,\(fmt(totalRevenueExVAT))\n"
            csv += "Tổng VAT đã thu,\(fmt(totalVAT))\n"
            csv += "VAT cần nộp (ước tính),\(fmt(estimatedVATPayable))\n"
            csv += "=====================================\n"
        }

        do {
            // Thêm BOM UTF-8 để Excel đọc đúng tiếng Việt
            var data = Data([0xEF, 0xBB, 0xBF])
            
            // Thêm footer đơn giản
            csv += "\n"
            csv += "=== KẾT THÚC BÁO CÁO TÀI CHÍNH ===\n"
            csv += "Được tạo bởi SmartKiot POS System\n"
            csv += "Cảm ơn bạn đã sử dụng!\n"
            csv += "=====================================\n"
            
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

    // MARK: - Helper Functions for Enhanced Export

    private func getDateRangeString(_ stats: [DailyFinancialStats]) -> String {
        guard !stats.isEmpty else { return "N/A" }
        let sortedStats = stats.sorted { $0.date < $1.date }
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM/yyyy"
        
        if let first = sortedStats.first, let last = sortedStats.last {
            if Calendar.current.isDate(first.date, inSameDayAs: last.date) {
                return df.string(from: first.date)
            } else {
                return "\(df.string(from: first.date)) - \(df.string(from: last.date))"
            }
        }
        return "N/A"
    }

    private func getRetailOrdersInRange(_ orders: [Bill], stats: [DailyFinancialStats]) -> [Bill] {
        guard !stats.isEmpty else { return [] }
        let sortedStats = stats.sorted { $0.date < $1.date }
        guard let startDate = sortedStats.first?.date,
              let endDate = sortedStats.last?.date else { return [] }
        
        let calendar = Calendar.current
        let endOfEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        return orders.filter { bill in
            !bill.isDeleted &&
            bill.createdAt >= startDate && bill.createdAt <= endOfEndDate
        }
    }

    private func getUniqueCustomerCount(orders: [Bill]) -> Int {
        let customerNames = Set(orders.compactMap { bill in
            let name = (bill.customerName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name.lowercased()
        })
        return customerNames.count
    }

    private func getTotalVATCollected(orders: [Bill]) -> Double {
        return orders.reduce(0) { $0 + $1.vatAmount }
    }

    struct TopSellingProduct {
        let name: String
        let quantity: Int
        let revenue: Double
    }

    private func getTopSellingProducts(orders: [Bill], limit: Int = 10) -> [TopSellingProduct] {
        var productStats: [String: (quantity: Int, revenue: Double)] = [:]
        
        for order in orders {
            for item in order.items {
                let key = item.name
                let existing = productStats[key] ?? (quantity: 0, revenue: 0)
                productStats[key] = (
                    quantity: existing.quantity + item.quantity,
                    revenue: existing.revenue + item.total
                )
            }
        }
        
        return productStats.map { (name, stats) in
            TopSellingProduct(name: name, quantity: stats.quantity, revenue: stats.revenue)
        }
        .sorted { $0.revenue > $1.revenue }
        .prefix(limit)
        .map { $0 }
    }

    struct WholesaleCustomerAnalysis {
        let name: String
        let phone: String
        let totalRevenue: Double
        let totalPaid: Double
        let totalDebt: Double
        let orderCount: Int
        let lastOrderDate: Date
    }

    private func analyzeWholesaleCustomers(transactions: [ProductionTransaction]) -> [WholesaleCustomerAnalysis] {
        var customerStats: [String: (revenue: Double, paid: Double, debt: Double, count: Int, lastDate: Date)] = [:]
        
        for tx in transactions {
            let customerKey = (tx.buyerName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !customerKey.isEmpty else { continue }
            
            let key = customerKey.lowercased()
            let existing = customerStats[key] ?? (revenue: 0, paid: 0, debt: 0, count: 0, lastDate: tx.createdAt)
            
            customerStats[key] = (
                revenue: existing.revenue + (tx.grandTotal ?? 0),
                paid: existing.paid + (tx.paidAmount ?? 0),
                debt: existing.debt + tx.effectiveDebt,
                count: existing.count + 1,
                lastDate: max(existing.lastDate, tx.createdAt)
            )
        }
        
        return customerStats.compactMap { (key, stats) in
            // Tìm transaction gần nhất để lấy tên và phone chính xác
            guard let recentTx = transactions
                .filter({ ($0.buyerName ?? "").lowercased() == key })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first else { return nil }
            
            return WholesaleCustomerAnalysis(
                name: recentTx.buyerName ?? "",
                phone: recentTx.buyerPhone ?? "",
                totalRevenue: stats.revenue,
                totalPaid: stats.paid,
                totalDebt: stats.debt,
                orderCount: stats.count,
                lastOrderDate: stats.lastDate
            )
        }
        .sorted { $0.totalRevenue > $1.totalRevenue }
    }

    struct InventoryItem {
        let name: String
        let stockQuantity: Int
        let costPrice: Double
        let totalValue: Double
        let category: String
    }

    private func getInventoryStats(products: [Product]) -> [InventoryItem] {
        return products
            .filter { $0.stockQuantity > 0 }
            .map { product in
                InventoryItem(
                    name: product.name,
                    stockQuantity: product.stockQuantity,
                    costPrice: product.costPrice,
                    totalValue: Double(product.stockQuantity) * product.costPrice,
                    category: product.category
                )
            }
            .sorted { $0.totalValue > $1.totalValue }
    }

    // Legacy functions for backward compatibility
    func exportToCSV(stats: [DailyFinancialStats]) -> URL? {
        return exportToCSV(stats: stats, wholesale: nil, orders: [], products: [])
    }
    
    func exportToCSV(stats: [DailyFinancialStats], wholesale: OrderViewModel.WholesaleStats? = nil) -> URL? {
        return exportToCSV(stats: stats, wholesale: wholesale, orders: [], products: [])
    }
    
    func getDateRange(_ range: ReportDateRange) -> (Date, Date) {
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
    
    private func drawDebtDetailsTable(orders: [Bill], context: CGContext, startY: inout CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        guard !orders.isEmpty else {
            let noDataText = "Không có công nợ"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 13),
                .foregroundColor: UIColor.gray
            ]
            noDataText.draw(at: CGPoint(x: margin, y: startY), withAttributes: attributes)
            startY += 25
            return
        }
        
        // Group orders by customer
        var customerDebts: [String: (orders: [Bill], totalAmount: Double, totalPaid: Double, totalDebt: Double, phone: String)] = [:]
        
        for order in orders {
            let customerName = (order.customerName?.isEmpty == false) ? order.customerName! : "Khách vãng lai"
            let phone = order.customerPhone ?? ""
            
            if customerDebts[customerName] == nil {
                customerDebts[customerName] = (orders: [], totalAmount: 0, totalPaid: 0, totalDebt: 0, phone: phone)
            }
            
            var customer = customerDebts[customerName]!
            customer.orders.append(order)
            customer.totalAmount += order.total
            customer.totalPaid += (order.paidAmount ?? 0)
            customer.totalDebt += order.effectiveDebt
            if customer.phone.isEmpty && !phone.isEmpty {
                customer.phone = phone
            }
            customerDebts[customerName] = customer
        }
        
        // Sort customers by total debt (descending)
        let sortedCustomers = customerDebts.sorted { $0.value.totalDebt > $1.value.totalDebt }
        
        let rowHeight: CGFloat = 20
        let columnWidths: [CGFloat] = [
            contentWidth * 0.05, // STT
            contentWidth * 0.25, // Khách hàng
            contentWidth * 0.15, // Điện thoại
            contentWidth * 0.10, // Số đơn
            contentWidth * 0.15, // Tổng tiền
            contentWidth * 0.15, // Đã trả
            contentWidth * 0.15  // Còn nợ
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        
        let headers = ["STT", "Khách hàng", "Điện thoại", "Số đơn", "Tổng tiền", "Đã trả", "Còn nợ"]
        
        // Draw header
        context.setFillColor(UIColor.systemRed.cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        var currentX = margin
        for (index, header) in headers.enumerated() {
            header.draw(in: CGRect(x: currentX + 2, y: startY + 4, width: columnWidths[index] - 4, height: rowHeight - 8), withAttributes: headerAttributes)
            currentX += columnWidths[index]
        }
        
        startY += rowHeight
        
        // Track totals
        var grandTotalAmount = 0.0
        var grandTotalPaid = 0.0
        var grandTotalDebt = 0.0
        
        // Draw customer debt rows
        for (index, (customerName, customerData)) in sortedCustomers.enumerated() {
            // Alternate row colors
            if index % 2 == 1 {
                context.setFillColor(UIColor.systemGray6.cgColor)
                context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            }
            
            // Draw border
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(0.3)
            context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
            
            // Prepare customer data
            let displayName = customerName.count > 20 ? String(customerName.prefix(17)) + "..." : customerName
            let displayPhone = customerData.phone.count > 12 ? String(customerData.phone.prefix(9)) + "..." : customerData.phone
            let orderCount = "\(customerData.orders.count)"
            let totalAmount = formatCurrency(customerData.totalAmount)
            let totalPaid = formatCurrency(customerData.totalPaid)
            let totalDebt = formatCurrency(customerData.totalDebt)
            
            // Add to grand totals
            grandTotalAmount += customerData.totalAmount
            grandTotalPaid += customerData.totalPaid
            grandTotalDebt += customerData.totalDebt
            
            let rowData = [
                "\(index + 1)",
                displayName,
                displayPhone,
                orderCount,
                totalAmount,
                totalPaid,
                totalDebt
            ]
            
            currentX = margin
            for (colIndex, data) in rowData.enumerated() {
                let textColor = (colIndex == 6) ? UIColor.red : UIColor.black
                var attributes = cellAttributes
                attributes[.foregroundColor] = textColor
                
                data.draw(in: CGRect(x: currentX + 2, y: startY + 2, width: columnWidths[colIndex] - 4, height: rowHeight - 4), withAttributes: attributes)
                currentX += columnWidths[colIndex]
            }
            
            startY += rowHeight
        }
        
        // Draw total row
        context.setFillColor(UIColor.systemRed.withAlphaComponent(0.2).cgColor)
        context.fill(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: margin, y: startY, width: contentWidth, height: rowHeight))
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.red
        ]
        
        let totalRowData = [
            "",
            "TỔNG CỘNG",
            "",
            "\(sortedCustomers.count) KH",
            formatCurrency(grandTotalAmount),
            formatCurrency(grandTotalPaid),
            formatCurrency(grandTotalDebt)
        ]
        
        currentX = margin
        for (colIndex, data) in totalRowData.enumerated() {
            data.draw(in: CGRect(x: currentX + 2, y: startY + 2, width: columnWidths[colIndex] - 4, height: rowHeight - 4), withAttributes: boldAttributes)
            currentX += columnWidths[colIndex]
        }
        
        startY += rowHeight
    }


