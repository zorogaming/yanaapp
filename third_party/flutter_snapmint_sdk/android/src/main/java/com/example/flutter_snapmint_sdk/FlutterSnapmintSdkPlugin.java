package com.example.flutter_snapmint_sdk;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.snapmint.merchantsdk.constants.SnapmintConfiguration;
import com.snapmint.merchantsdk.snapmintsdk.NewCheckoutWebViewActivity;

import org.json.JSONObject;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/** FlutterSnapmintSdkPlugin */
public class FlutterSnapmintSdkPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private static final String TAG = "FlutterSnapmintSdkPlugin";
  private static Result pendingResult;

  private Context context;
  private Activity activity;
  private ActivityPluginBinding activityBinding;



  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_snapmint_sdk");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();

  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if(call.method.equals("openSnapmintMerchant")) {
      if (activity == null) {
        result.error("NO_ACTIVITY", "Activity is null", null);
        return;
      }

      String checkoutUrl = null;
      try {
        checkoutUrl = (String) call.arguments;
      } catch (Exception e) {
        // Support legacy JSON payload: extract base_url and params to build URL if needed
        try {
          JSONObject json = new JSONObject(String.valueOf(call.arguments));
          checkoutUrl = json.optString("redirect_url", null);
        } catch (Exception ignored) {}
      }

      if (checkoutUrl == null || checkoutUrl.trim().isEmpty()) {
        result.error("INVALID_URL", "Invalid checkout URL", null);
        return;
      }

      pendingResult = result;
      Log.d(TAG, "Launching Snapmint SDK with redirect_url: " + checkoutUrl);
      Intent intent = new Intent(activity, NewCheckoutWebViewActivity.class);
      intent.putExtra("redirect_url", checkoutUrl);
      try {
        activity.startActivityForResult(intent, SnapmintConfiguration.SNAPMINT_PAYMENT);
      } catch (Exception e) {
        pendingResult = null;
        result.error("START_FAILED", e.getMessage(), null);
      }
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
  }

  // ActivityAware
  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    this.activityBinding = binding;
    this.activity = binding.getActivity();
    binding.addActivityResultListener(this);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    if (activityBinding != null) activityBinding.removeActivityResultListener(this);
    activityBinding = null;
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    if (activityBinding != null) activityBinding.removeActivityResultListener(this);
    activityBinding = null;
    activity = null;
  }

  // Activity result callback from Snapmint SDK
  @Override
  public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
    if (requestCode == SnapmintConfiguration.SNAPMINT_PAYMENT) {
      try {
        String status = data != null ? data.getStringExtra(SnapmintConfiguration.STATUS) : null;
        String payload = data != null ? data.getStringExtra("data") : null;
        Log.d(TAG, "Activity result received. status=" + status + ", payload=" + (payload != null ? payload : "<null>"));
        JSONObject resp = new JSONObject();
        if (status != null && status.equalsIgnoreCase(SnapmintConfiguration.SUCCESS)) {
          resp.put("status", "success");
          resp.put("statusCode", 200);
          if (payload != null) resp.put("responseMsg", payload);
        } else {
          resp.put("status", "failure");
          resp.put("statusCode", 400);
          if (payload != null) resp.put("responseMsg", payload);
        }
        Log.d(TAG, "Returning JSON to Dart: " + resp.toString());
        if (pendingResult != null) {
          pendingResult.success(resp.toString());
          pendingResult = null;
        }
      } catch (Exception e) {
        Log.e(TAG, "Error building activity result JSON", e);
        if (pendingResult != null) {
          pendingResult.error("PARSE_ERROR", e.getMessage(), null);
          pendingResult = null;
        }
      }
      return true;
    }
    return false;
  }
}
