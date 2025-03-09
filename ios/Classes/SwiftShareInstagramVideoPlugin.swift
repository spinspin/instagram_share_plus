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
            checkAssetAndShare(path: path, result: result)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        self?.checkAssetAndShare(path: path, result: result)
                    } else {
                        result("failed")
                    }
                }
            }
        default:
            result("failed")
        }
    }
    
    private func checkAssetAndShare(path: String, result: @escaping FlutterResult) {
        // First, check if we can get a PHAsset from the file URL directly
        // This is the most reliable way when available
        let fileURL = URL(fileURLWithPath: path)
        let fileName = fileURL.lastPathComponent
        
        // Get file attributes for potential matching
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: path)
        let fileCreationDate = fileAttributes?[.creationDate] as? Date
        let fileSize = (fileAttributes?[.size] as? NSNumber)?.int64Value ?? 0
        
        // Determine media type from extension
        let fileExtension = fileURL.pathExtension.lowercased()
        let isImage = ["jpg", "jpeg", "png", "heic"].contains(fileExtension)
        
        // Try to find the asset by filename first
        let fileNameOptions = PHFetchOptions()
        fileNameOptions.predicate = NSPredicate(format: "filename CONTAINS[c] %@", fileName)
        let fileNameResult = PHAsset.fetchAssets(with: fileNameOptions)
        
        if fileNameResult.count > 0, let asset = fileNameResult.firstObject {
            // We found a matching asset by filename
            openInstagramWithIdentifier(localId: asset.localIdentifier, result: result)
            return
        }
        
        // If no match by filename, try by creation date for recent files
        if let fileCreationDate = fileCreationDate {
            let dateOptions = PHFetchOptions()
            // Look for assets created within 5 minutes of this file
            let startDate = fileCreationDate.addingTimeInterval(-300) // 5 minutes before
            let endDate = fileCreationDate.addingTimeInterval(300)    // 5 minutes after
            dateOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
            
            // Filter by media type
            let mediaTypeResult: PHFetchResult<PHAsset>
            if isImage {
                mediaTypeResult = PHAsset.fetchAssets(with: .image, options: dateOptions)
            } else {
                mediaTypeResult = PHAsset.fetchAssets(with: .video, options: dateOptions)
            }
            
            if mediaTypeResult.count > 0, let asset = mediaTypeResult.firstObject {
                // Found a match by date and media type
                openInstagramWithIdentifier(localId: asset.localIdentifier, result: result)
                return
            }
        }
        
        // If we get here, we didn't find a matching asset - save it
        saveAndShare(path: path, result: result)
    }
    
    private func saveAndShare(path: String, result: @escaping FlutterResult) {
        let fileURL = URL(fileURLWithPath: path)
        var localIdentifier: String?
        
        PHPhotoLibrary.shared().performChanges({
            // Create request inside the performChanges block
            let createAssetRequest: PHAssetChangeRequest
            let fileExtension = fileURL.pathExtension.lowercased()
            
            if ["jpg", "jpeg", "png", "heic"].contains(fileExtension) {
                // It's an image
                guard let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL) else {
                    DispatchQueue.main.async {
                        result("failed")
                    }
                    return
                }
                createAssetRequest = request
            } else {
                // It's a video or other media
                guard let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL) else {
                    DispatchQueue.main.async {
                        result("failed")
                    }
                    return
                }
                createAssetRequest = request
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
