//
//  ViewController.swift
//  QRCodeReader
//
//  Created by Takaki Yoneyama on 2018/08/28.
//  Copyright © 2018年 Takaki Yoneyama. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage
import Vision

class QRCodeFrameView: UIView {
    let payloardHashValue: Int
    var timer: Timer?

    init(payloardHashValue: Int) {
        self.payloardHashValue = payloardHashValue
        super.init(frame: CGRect.zero)
        self.layer.borderWidth = 4
        self.layer.borderColor = #colorLiteral(red: 0.8725296855, green: 0.2692160606, blue: 0.1768482924, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startSelfRemoveTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { [weak self] (_) in
            self?.removeFromSuperview()
        })
    }

}

class ViewController: UIViewController {

    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var symbolVersionLabel: UILabel!
    @IBOutlet private weak var stringValueLabel: CopyableLabel!
    @IBOutlet private weak var qrCodeImageView: UIImageView!
    @IBOutlet private weak var binaryModeButton: UIButton!

    private let captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        preconditionFailure()
    }()

    var errorCorrectedPayload: Data? {
        didSet {
            DispatchQueue.main.async {
                self.binaryModeButton.isEnabled = (self.errorCorrectedPayload != nil) ? true : false
            }
        }
    }

    var symbolVersion: Int? {
        didSet {
            DispatchQueue.main.async {
                if let symbolVersion = self.symbolVersion {
                    self.symbolVersionLabel.text = "SymbolVersion: " + String(symbolVersion)
                } else {
                    self.symbolVersionLabel.text = nil
                }
            }
        }
    }

    var qrCodeFrameViews: [QRCodeFrameView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard UIImagePickerController.isCameraDeviceAvailable(.front) else { return }
        previewLayer.frame = previewView.bounds
    }
    

    private func setup() {
        guard UIImagePickerController.isCameraDeviceAvailable(.front),
            let videoDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global())
        metadataOutput.metadataObjectTypes = [.qr]

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = previewView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    private func showQRCodeData(in metadata: AVMetadataMachineReadableCodeObject) {
        guard metadata.type == .qr,
        let descriptor = metadata.descriptor as? CIQRCodeDescriptor else { return }

        if let qrCode = previewLayer.transformedMetadataObject(for: metadata) {
            let hashValue = descriptor.errorCorrectedPayload.hashValue
            qrCodeFrameViews.removeAll { $0.superview == nil }
            if let qrCodeFrameView = qrCodeFrameViews.first(where: { $0.payloardHashValue == hashValue }) {
                qrCodeFrameView.startSelfRemoveTimer()
                qrCodeFrameView.frame = qrCode.bounds
            } else {
                let qrCodeFrameView = QRCodeFrameView(payloardHashValue: hashValue)
                qrCodeFrameViews.append(qrCodeFrameView)
                view.addSubview(qrCodeFrameView)
                qrCodeFrameView.frame = qrCode.bounds
                qrCodeFrameView.startSelfRemoveTimer()
            }
        }

        if let stringValue = metadata.stringValue {
            stringValueLabel.text = stringValue
        }
    }

    private func generateQRCodeImage(from descriptor: CIQRCodeDescriptor) -> UIImage? {
        let inputParams: [String: Any] = ["inputBarcodeDescriptor": descriptor]
        let barcodeCreationFilter = CIFilter(name: "CIBarcodeGenerator", parameters: inputParams)
        guard let outputImage = barcodeCreationFilter?.outputImage,
            let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
                return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func readQRCode(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNDetectBarcodesRequest()
        try? handler.perform([request])

        guard let results = request.results as? [VNBarcodeObservation],
            let result = results.first(where: { $0.payloadStringValue != nil }),
            let descriptor = result.barcodeDescriptor as? CIQRCodeDescriptor
            else { return }

        // VNBarcodeObservation#payloadStringValue の値は
        // AVMetadataMachineReadableCodeObject#stringValue とたぶん同じ
        stringValueLabel.text = result.payloadStringValue
        qrCodeImageView.image = generateQRCodeImage(from: descriptor)

        symbolVersion = descriptor.symbolVersion
        errorCorrectedPayload = descriptor.errorCorrectedPayload
    }

    private func readQRCodeFromPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    @IBAction private func readFromPhotoLibraryButtonDidTap(_ sender: UIButton) {
        readQRCodeFromPhotoLibrary()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier,
            identifier == "goToBinaryMode",
            let destination = segue.destination as? BinaryModeViewController,
            let errorCorrectedPayload = errorCorrectedPayload,
            let symbolVersion = symbolVersion else { return }

        let binary = Binary(data: errorCorrectedPayload)
        destination.binary = binary
        destination.symbolVersion = symbolVersion
    }

}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate, UINavigationControllerDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for metadata in metadataObjects {
            guard let metadata = metadata as? AVMetadataMachineReadableCodeObject, metadata.type == .qr else { continue }

            DispatchQueue.main.async {
                self.showQRCodeData(in: metadata)
            }

            guard let descriptor = metadata.descriptor as? CIQRCodeDescriptor else { continue }
            symbolVersion = descriptor.symbolVersion

            // CIQRCodeDescriptor#errorCorrectedPayload は誤り訂正済みのData.
            errorCorrectedPayload = descriptor.errorCorrectedPayload

            let qrCodeImage = generateQRCodeImage(from: descriptor)
            DispatchQueue.main.async {
                self.qrCodeImageView.image = qrCodeImage
            }
        }
    }

}

extension ViewController: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            readQRCode(in: image)
        }

        dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

}
