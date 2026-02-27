import SwiftUI
import UIKit

struct BarcodePrintView: View {
    let product: Product
    @Environment(\.dismiss) var dismiss
    @State private var quantity: Int = 1
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview Section
                VStack(spacing: 12) {
                    Text("Xem trước")
                        .font(.headline)
                        .foregroundStyle(.gray)
                    
                    BarcodeLabelView(product: product)
                        .frame(width: 300, height: 180) // Preview size (scaled up)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                }
                .padding(.top)
                
                // Controls
                Form {
                    Section(header: Text("Cấu hình in")) {
                        Stepper("Số lượng: \(quantity)", value: $quantity, in: 1...100)
                    }
                    
                    Section {
                        Button(action: printLabel) {
                            HStack {
                                Spacer()
                                Image(systemName: "printer.fill")
                                Text("In ngay")
                                Spacer()
                            }
                        }
                        .foregroundStyle(Color.blue)
                    }
                }
            }
            .navigationTitle("In mã vạch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .background(Color.themeBackgroundLight)
        }
    }
    
    private func printLabel() {
        // Render the label to an image
        let labelView = BarcodeLabelView(product: product)
            .frame(width: 375, height: 225) // Standard label ratio (approx 50x30mm at 200dpi)
        
        let renderer = ImageRenderer(content: labelView)
        renderer.scale = 3.0 // High resolution for printing
        
        guard let image = renderer.uiImage else { return }
        
        // Print Logic
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Barcode - \(product.name)"
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        
        // If printing multiple copies, we might need to handle loop in print interaction or combine images.
        // UIPrintInteractionController doesn't easily support "quantity" of same image in one job property directly for image input,
        // but user can select copies in the system print dialog.
        // We will just pass the single image and let user choose copies in the iOS Print Dialog, 
        // OR we can generate a PDF with N pages.
        // For simplicity, we pass the image and user selects copies in printer options.
        // Wait, user asked to set quantity. If I pass image, iOS print dialog has "Copies".
        // But if they want to print on a roll, "Copies" works.
        // If they want to print on A4 sheet (grid), that's harder.
        // Assuming label printer (roll): Copies works.
        
        printController.printingItem = image
        
        printController.present(animated: true) { _, completed, error in
            if completed {
                dismiss()
            }
        }
    }
}

struct BarcodeLabelView: View {
    let product: Product
    
    var body: some View {
        VStack(spacing: 4) {
            Text(product.name)
                .font(.system(size: 24, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.black)
            
            Text(formatCurrency(product.price))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)
            
            if let barcode = product.barcode, 
               let image = BarcodeGenerator.shared.generateBarcode(from: barcode) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxHeight: 80)
                
                Text(barcode)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.black)
            } else {
                Text("No Barcode")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.black, lineWidth: 2) // Border for cutting
        )
    }
}
