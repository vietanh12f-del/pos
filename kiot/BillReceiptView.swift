import SwiftUI

struct BillReceiptView: View {
    let items: [OrderItem]
    let totalAmount: Double
    let dateString: String
    let qrURL: URL?
    let qrImage: UIImage?
    let billPayload: String?
    let showButtons: Bool
    let onComplete: ((Bool) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Khách lẻ")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                Text(dateString)
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            DottedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4])).frame(height: 1).foregroundStyle(.gray.opacity(0.3)).padding(.horizontal)
            
            VStack(spacing: 16) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        // Product Image
                        if let data = item.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        } else {
                            Image(systemName: item.systemImage ?? "cart.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.themePrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.themePrimary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.themeTextDark)
                            Text("\(item.quantity) x \(formatCurrency(item.price))")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray)
                            
                            if item.discount > 0 {
                                Text("-\(formatCurrency(item.discount))")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        Text(formatCurrency(item.total))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                    }
                }
            }
            .padding()
            
            DottedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4])).frame(height: 1).foregroundStyle(.gray.opacity(0.3)).padding(.horizontal)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Tổng tiền hàng")
                        .foregroundStyle(Color.gray)
                    Spacer()
                    Text(formatCurrency(totalAmount))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                }
                HStack {
                    Text("Tổng cộng")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                    Text(formatCurrency(totalAmount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quét mã thanh toán")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray)
                        
                        // Dynamic Bank Info Display
                        let bankName = StoreManager.shared.currentStore?.bankName ?? "VCB"
                        let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber ?? "9967861809"
                        
                        Text("\(bankName) - \(bankAccount)")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.themeTextDark)
                        
                        Text("Chủ TK: NGUYEN THI BICH NGOC")
                            .font(.footnote)
                            .foregroundStyle(Color.gray)
                    }
                    
                    Spacer()
                    
                    if let qrImage = qrImage {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                    } else if let _ = qrURL {
                        // Placeholder while loading or if nil
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .overlay(ProgressView())
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            if let payload = billPayload {
                VStack(spacing: 8) {
                    if let qrImage = generateQRCode(from: payload) {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5)
                    }
                    
                    Text("Mã đơn hàng (Dành cho Shipper)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            
            if showButtons {
                VStack(spacing: 12) {
                    Button(action: { onComplete?(true) }) {
                        Text("Đã nhận tiền")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themePrimary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { onComplete?(false) }) {
                        Text("Chưa nhận tiền (Nợ)")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .background(Color.white)
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        return nil
    }
}

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}
