import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIViewController {
        return ShareViewController(items: items)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    // Internal ViewController to handle presentation
    class ShareViewController: UIViewController {
        var items: [Any]
        
        init(items: [Any]) {
            self.items = items
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            // Only present if not already presenting
            if presentedViewController == nil {
                let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                
                // For iPad support
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                // Dismiss the sheet when activity VC is dismissed
                activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                    self?.dismiss(animated: true)
                }
                
                present(activityVC, animated: true)
            }
        }
    }
}
