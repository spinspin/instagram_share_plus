import Flutter
import UIKit
import Photos
import MobileCoreServices
import os.log

public class SwiftShareInstagramVideoPlugin: NSObject, FlutterPlugin {
    
    private let logger = OSLog(subsystem: "com.yourapp.instagram_share_plus", category: "InstagramShare")
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "instagram_share_plus", binaryMessenger: registrar.messenger())
        let instance = SwiftShareInstagramVideoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "shareVideoToInstagram":
            os_log("ShareVideoToInstagram called with args: %{public}@", log: logger, type: .debug, String(describing: call.arguments))
            
            if let args = call.arguments as? [String: Any] {
                if let localIdentifier = args["localIdentifier"] as? String {
                    // If we already have a localIdentifier, use it directly
                    os_log("Using local identifier: %{public}@", log: logger, type: .debug, localIdentifier)
                    shareToInstagramWithIdentifier(localIdentifier: localIdentifier, result: result)
                } else if let filePath = args["path"] as? String {
                    // If we have a file path, first try to find its identifier or save it
                    os_log("Using file path: %{public}@", log: logger, type: .debug, filePath)
                    
                    // Check if file exists
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: filePath) {
                        os_log("File exists at path", log: logger, type: .debug)
                        shareToInstagramWithFilePath(filePath: filePath, result: result)
                    } else {
                        os_log("File does not exist at path!", log: logger, type: .error)
                        result("failed")
                    }
                } else {
                    os_log("Missing required parameter", log: logger, type: .error)
                    result("failed")
                }
            } else {
                os_log("Invalid arguments", log: logger, type: .error)
                result("failed")
            }
        default:
            os_log("Method not implemented: %{public}@", log: logger, type: .error, call.method)
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func shareToInstagramWithIdentifier(localIdentifier: String, result: @escaping FlutterResult) {
        // Construct the Instagram URL with the provided local identifier
        let instagramURL = URL(string: "instagram://library?LocalIdentifier=\(localIdentifier)")
        os_log("Instagram URL: %{public}@", log: logger, type: .debug, instagramURL?.absoluteString ?? "nil")
        
        // Check if Instagram is installed and can handle the URL
        if let url = instagramURL, UIApplication.shared.canOpenURL(url) {
            os_log("Instagram can handle URL", log: logger, type: .debug)
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        os_log("Successfully opened Instagram", log: logger, type: .debug)
                        result("success")
                    } else {
                        os_log("Failed to open Instagram", log: logger, type: .error)
                        result("failed")
                    }
                }
            }
        } else {
            os_log("Instagram not installed or cannot handle URL", log: logger, type: .error)
            result("instagram_not_installed")
        }
    }
    
    private func shareToInstagramWithFilePath(filePath: String, result: @escaping FlutterResult) {
        let fileURL = URL(fileURLWithPath: filePath)
        os_log("File URL: %{public}@", log: logger, type: .debug, fileURL.absoluteString)
        os_log("File extension: %{public}@", log: logger, type: .debug, fileURL.pathExtension)
        
        // Request permission if needed
        let status = PHPhotoLibrary.authorizationStatus()
        os_log("Photo library authorization status: %{public}d", log: logger, type: .debug, status.rawValue)
        
        switch status {
        case .authorized:
            saveToPhotoLibrary(fileURL: fileURL, result: result)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.saveToPhotoLibrary(fileURL: fileURL, result: result)
                    } else {
                        os_log("Photo library permission denied", log: logger, type: .error)
                        result("failed")
                    }
                }
            }
        default:
            os_log("No permission to access photo library", log: logger, type: .error)
            result("failed")
        }
    }
    
    private func saveToPhotoLibrary(fileURL: URL, result: @escaping FlutterResult) {
        // First, check if this file is already in the photo library
        PHPhotoLibrary.shared().performChanges({
            // Create a request to save the image or video to the photo library
            let createAssetRequest: PHAssetChangeRequest
            
            do {
                if fileURL.pathExtension.lowercased() == "jpg" || 
                   fileURL.pathExtension.lowercased() == "jpeg" || 
                   fileURL.pathExtension.lowercased() == "png" {
                    // It's an image
                    os_log("Saving as image", log: self.logger, type: .debug)
                    createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)!
                } else {
                    // It's a video or other media
                    os_log("Saving as video", log: self.logger, type: .debug)
                    createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)!
                }
                
                // Get the placeholder for the new asset
                if let placeholder = createAssetRequest.placeholderForCreatedAsset {
                    // We need to store this somewhere accessible from the completion handler
                    DispatchQueue.main.async {
                        os_log("Got placeholder with identifier: %{public}@", log: self.logger, type: .debug, placeholder.localIdentifier)
                        self.handleAssetCreationCompletion(placeholderLocalIdentifier: placeholder.localIdentifier, result: result)
                    }
                } else {
                    os_log("No placeholder received", log: self.logger, type: .error)
                }
            } catch {
                os_log("Error creating asset request: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }) { success, error in
            if success {
                os_log("Successfully saved to photo library", log: self.logger, type: .debug)
            } else {
                os_log("Failed to save to photo library: %{public}@", log: self.logger, type: .error, error?.localizedDescription ?? "Unknown error")
                DispatchQueue.main.async {
                    result("failed")
                }
            }
        }
    }
    
    private func handleAssetCreationCompletion(placeholderLocalIdentifier: String, result: @escaping FlutterResult) {
        // Fetch the newly created asset using the placeholder's local identifier
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [placeholderLocalIdentifier], options: nil)
        
        if let asset = fetchResult.firstObject {
            // Now we have the actual asset, get its local identifier
            os_log("Asset found with identifier: %{public}@", log: logger, type: .debug, asset.localIdentifier)
            shareToInstagramWithIdentifier(localIdentifier: asset.localIdentifier, result: result)
        } else {
            os_log("Asset not found for identifier: %{public}@", log: logger, type: .error, placeholderLocalIdentifier)
            result("failed")
        }
    }
}
