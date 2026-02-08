import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }
    
    class Coordinator: NSObject, BarcodeScannerDelegate {
        var onScan: (String) -> Void
        
        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }
        
        func didFind(code: String) {
            onScan(code)
        }
    }
}

protocol BarcodeScannerDelegate: AnyObject {
    func didFind(code: String)
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: BarcodeScannerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Add a visual guide (overlay)
        addOverlay()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
    }
    
    func found(code: String) {
        delegate?.didFind(code: code)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    private func addOverlay() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.clear
        overlay.layer.borderColor = UIColor.green.cgColor
        overlay.layer.borderWidth = 2
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.widthAnchor.constraint(equalToConstant: 250),
            overlay.heightAnchor.constraint(equalToConstant: 250)
        ])
        
        let label = UILabel()
        label.text = "Di chuyển camera đến mã vạch"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: overlay.bottomAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.heightAnchor.constraint(equalToConstant: 36),
            label.widthAnchor.constraint(equalToConstant: 250)
        ])
    }
}
