import Flutter
import UIKit
import Photos
import MobileCoreServices

public class SwiftShareInstagramVideoPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "instagram_share_plus", binaryMessenger: registrar.messenger())
        let instance = SwiftShareInstagramVideoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "shareVideoToInstagram" else {
            result(FlutterMethodNotImplemented)
            return
        }
        
        guard let args = call.arguments as? [String: Any] else {
            result("failed")
            return
        }
        
        guard let path = args["path"] as? String else {
            result("failed")
            return
        }
        
        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            result("failed")
            return
        }
        
        // Check photo library permissions
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            saveAndShare(path: path, result: result)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        self?.saveAndShare(path: path, result: result)
                    } else {
                        result("failed")
                    }
                }
            }
        default:
            result("failed")
        }
    }
    
    private func saveAndShare(path: String, result: @escaping FlutterResult) {
        let fileURL = URL(fileURLWithPath: path)
        
        var assetIdentifier: String?
        var saveError: Error?
        
        let saveOperation = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL) ??
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        
        if let placeholder = saveOperation?.placeholderForCreatedAsset {
            assetIdentifier = placeholder.localIdentifier
        }
        
        PHPhotoLibrary.shared().performChanges({
            // Changes already made above
        }) { success, error in
            DispatchQueue.main.async {
                if success, let localId = assetIdentifier {
                    self.openInstagramWithIdentifier(localId: localId, result: result)
                } else {
                    result("failed")
                }
            }
        }
    }
    
    private func openInstagramWithIdentifier(localId: String, result: @escaping FlutterResult) {
        let instagramURL = URL(string: "instagram://library?LocalIdentifier=\(localId)")
        
        guard let url = instagramURL, UIApplication.shared.canOpenURL(url) else {
            result("instagram_not_installed")
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            result(success ? "success" : "failed")
        }
    }
}
