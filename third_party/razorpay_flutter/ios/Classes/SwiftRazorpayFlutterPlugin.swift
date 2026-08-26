import Flutter
import Razorpay
import UIKit

public class SwiftRazorpayFlutterPlugin: NSObject, FlutterPlugin {

    private var razorpayDelegate = RazorpayDelegate()
    private static let CHANNEL_NAME = "razorpay_flutter"
    private static let MERCHANT_EVENT_CHANNEL_NAME = "razorpay_flutter/merchant_events"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: registrar.messenger())
        let instance = SwiftRazorpayFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let merchantEventChannel = FlutterEventChannel(name: MERCHANT_EVENT_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        merchantEventChannel.setStreamHandler(instance)
    }

    /// Returns the visible view controller so the SDK presents checkout without disturbing Flutter navigation.
    private static func visibleViewController() -> UIViewController? {
        guard let root = rootViewController() else { return nil }
        return topMostViewController(from: root)
    }

    /// Returns the root view controller. Prefers scene-based API (iOS 13+).
    private static func rootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                if let vc = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    return vc
                }
                if let vc = windowScene.windows.first?.rootViewController {
                    return vc
                }
            }
        }
        return UIApplication.shared.keyWindow?.rootViewController
    }

    private static func topMostViewController(from viewController: UIViewController) -> UIViewController {
        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return topMostViewController(from: visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topMostViewController(from: selectedViewController)
        }

        if let presentedViewController = viewController.presentedViewController {
            return topMostViewController(from: presentedViewController)
        }

        return viewController
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "open":
            let options = call.arguments as! Dictionary<String, Any>
            let viewController = Self.visibleViewController()
            razorpayDelegate.open(options: options, result: result, from: viewController)
        case "close":
            razorpayDelegate.closeCheckout(result: result)
        case "resync":
            razorpayDelegate.resync(result: result)
        case "subscribeToAnalyticsEvents":
            let args = call.arguments as? [String: Any]
            let events = (args?["events"] as? [String]) ?? []
            razorpayDelegate.subscribeToAnalyticsEvents(events: events)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension SwiftRazorpayFlutterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        razorpayDelegate.merchantEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        razorpayDelegate.merchantEventSink = nil
        return nil
    }
}
