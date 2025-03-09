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
        switch call.method {
        case "shareVideoToInstagram":
            if let args = call.arguments as? [String: Any] {
                if let localIdentifier = args["localIdentifier"] as? String {
                    // If we already have a localIdentifier, use it directly
                    shareToInstagramWithIdentifier(localIdentifier: localIdentifier, result: result)
                } else if let filePath = args["filePath"] as? String {
                    // If we have a file path, first try to find its identifier or save it
                    shareToInstagramWithFilePath(filePath: filePath, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", 
                                      message: "Missing required parameter 'localIdentifier' or 'filePath'", 
                                      details: nil))
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", 
                                  message: "Invalid arguments", 
                                  details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func shareToInstagramWithIdentifier(localIdentifier: String, result: @escaping FlutterResult) {
        // Construct the Instagram URL with the provided local identifier
        let instagramURL = URL(string: "instagram://library?LocalIdentifier=\(localIdentifier)")
        
        // Check if Instagram is installed and can handle the URL
        if let url = instagramURL, UIApplication.shared.canOpenURL(url) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        result("success")
                    } else {
                        result(FlutterError(code: "INSTAGRAM_ERROR", 
                                          message: "Failed to open Instagram", 
                                          details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "INSTAGRAM_NOT_AVAILABLE", 
                              message: "Instagram is not installed or cannot handle this media", 
                              details: nil))
        }
    }
    
    private func shareToInstagramWithFilePath(filePath: String, result: @escaping FlutterResult) {
        let fileURL = URL(fileURLWithPath: filePath)
        
        // First, check if this file is already in the photo library
        PHPhotoLibrary.shared().performChanges({
            // Create a request to save the image or video to the photo library
            let createAssetRequest: PHAssetChangeRequest
            
            if UTTypeConformsTo(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileURL.pathExtension as CFString, nil)!.takeRetainedValue(), kUTTypeImage) {
                // It's an image
                createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)!
            } else {
                // It's a video or other media
                createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)!
            }
            
            // Get the placeholder for the new asset
            if let placeholder = createAssetRequest.placeholderForCreatedAsset {
                // We need to store this somewhere accessible from the completion handler
                DispatchQueue.main.async {
                    self.handleAssetCreationCompletion(placeholderLocalIdentifier: placeholder.localIdentifier, result: result)
                }
            }
        }) { success, error in
            if !success {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SAVE_ERROR", 
                                      message: "Failed to save media to photo library: \(error?.localizedDescription ?? "Unknown error")", 
                                      details: nil))
                }
            }
        }
    }
    
    private func handleAssetCreationCompletion(placeholderLocalIdentifier: String, result: @escaping FlutterResult) {
        // Fetch the newly created asset using the placeholder's local identifier
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [placeholderLocalIdentifier], options: nil)
        
        if let asset = fetchResult.firstObject {
            // Now we have the actual asset, get its local identifier
            shareToInstagramWithIdentifier(localIdentifier: asset.localIdentifier, result: result)
        } else {
            result(FlutterError(code: "ASSET_NOT_FOUND", 
                              message: "Failed to retrieve saved asset", 
                              details: nil))
        }
    }
}
