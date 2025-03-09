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
        var localIdentifier: String?
        
        PHPhotoLibrary.shared().performChanges({
            // Create request inside the performChanges block
            let createAssetRequest: PHAssetChangeRequest
            let fileExtension = fileURL.pathExtension.lowercased()
            
            if fileExtension == "jpg" || fileExtension == "jpeg" || fileExtension == "png" {
                // It's an image
                createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)!
            } else {
                // It's a video or other media
                createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)!
            }
            
            // Store the placeholder identifier for later use
            if let placeholder = createAssetRequest.placeholderForCreatedAsset {
                localIdentifier = placeholder.localIdentifier
            }
            
        }) { success, error in
            DispatchQueue.main.async {
                if success, let localId = localIdentifier {
                    // Wait a moment for the asset to be fully available
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.fetchAssetAndShare(localId: localId, result: result)
                    }
                } else {
                    result("failed")
                }
            }
        }
    }
    
    private func fetchAssetAndShare(localId: String, result: @escaping FlutterResult) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        
        if let asset = fetchResult.firstObject {
            openInstagramWithIdentifier(localId: asset.localIdentifier, result: result)
        } else {
            result("failed")
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
