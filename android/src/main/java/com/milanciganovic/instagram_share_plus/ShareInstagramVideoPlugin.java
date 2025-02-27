package com.milanciganovic.instagram_share_plus;

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.StrictMode;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * InstagramsharePlugin
 */
public class ShareInstagramVideoPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  /// the authorities for FileProvider
  private static final int CODE_ASK_PERMISSION = 100;
  private static final String INSTAGRAM_PACKAGE_NAME = "com.instagram.android";

  private String mPath;
  private String mType;
  private MethodChannel mChannel;
  private Context mContext;

  private Activity mActivity;
  private Result pendingResult;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    mContext = flutterPluginBinding.getApplicationContext();
    mChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "instagram_share_plus");
    mChannel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    mChannel.setMethodCallHandler(null);
    mChannel = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("shareVideoToInstagram")) {
      if (pendingResult != null) {
        result.error("ALREADY_ACTIVE", "A share operation is already in progress", null);
        return;
      }
      
      pendingResult = result;
      mPath = call.argument("path");
      mType = call.argument("type");
      
      // Check if Instagram is installed first
      if (!instagramInstalled()) {
        // Return a specific response instead of opening Play Store
        pendingResult.success("instagram_not_installed");
        pendingResult = null;
        return;
      }
      
      if (!shareToInstagram(mPath, mType)) {
        pendingResult.success("failed");
        pendingResult = null;
      } else {
        // We'll complete this in handleActivityResult
        // Success result will be set there
        pendingResult.success("success");
        pendingResult = null;
      }
    } else {
      result.notImplemented();
    }
  }

  private boolean checkPermission() {
    return ContextCompat.checkSelfPermission(mContext, Manifest.permission.WRITE_EXTERNAL_STORAGE)
            == PackageManager.PERMISSION_GRANTED;
  }

  private void requestPermission() {
    ActivityCompat.requestPermissions(mActivity, new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, CODE_ASK_PERMISSION);
  }

  private boolean instagramInstalled() {
    try {
      PackageManager pm = mContext.getPackageManager();
      pm.getPackageInfo(INSTAGRAM_PACKAGE_NAME, PackageManager.GET_ACTIVITIES);
      return true;
    } catch (PackageManager.NameNotFoundException e) {
      return false;
    }
  }

  private boolean shareToInstagram(String path, String type) {
    String mediaType = "";
    if ("image".equals(type)) {
        mediaType = "image/jpeg";
    } else {
        mediaType = "video/*";
    }

    if (ShareUtils.shouldRequestPermission(path)) {
        if (!checkPermission()) {
            requestPermission();
            return false;
        }
    }

    File f = new File(path);
    Uri uri = ShareUtils.getUriForFile(mContext, f);

    StrictMode.VmPolicy.Builder builder = new StrictMode.VmPolicy.Builder();
    StrictMode.setVmPolicy(builder.build());
    
    // Create explicit intent for Instagram's main app, not Direct
    Intent shareIntent = new Intent(Intent.ACTION_SEND);
    shareIntent.setPackage(INSTAGRAM_PACKAGE_NAME); // com.instagram.android
    // Explicitly avoid Direct
    shareIntent.setClassName("com.instagram.android", "com.instagram.share.handleractivity.ShareHandlerActivity");
    shareIntent.putExtra(Intent.EXTRA_STREAM, uri);
    shareIntent.setType(mediaType);
    shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
    // Add FLAG_ACTIVITY_NEW_TASK flag
    shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    
    try {
        mContext.startActivity(shareIntent);
        return true;
    } catch (ActivityNotFoundException ex) {
        // If specific activity not found, try general Instagram intent
        Intent generalIntent = new Intent(Intent.ACTION_SEND);
        generalIntent.setPackage(INSTAGRAM_PACKAGE_NAME);
        generalIntent.putExtra(Intent.EXTRA_STREAM, uri);
        generalIntent.setType(mediaType);
        generalIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        // Add FLAG_ACTIVITY_NEW_TASK flag here too
        generalIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        
        try {
            mContext.startActivity(generalIntent);
            return true;
        } catch (ActivityNotFoundException e) {
            // Instead of opening Play Store, we'll just return false
            return false;
        }
    }
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    mActivity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    // Handle activity detachment for config changes
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    mActivity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    mActivity = null;
  }
}
