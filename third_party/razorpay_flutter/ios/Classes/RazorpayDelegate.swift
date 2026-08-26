import Flutter
import Razorpay
import RazorpayCore
import UIKit

public class RazorpayDelegate: NSObject, RazorpayPaymentCompletionProtocol, ExternalWalletSelectionProtocol, RazorpayEventCallback {
    
    static let CODE_PAYMENT_SUCCESS = 0
    static let CODE_PAYMENT_ERROR = 1
    static let CODE_PAYMENT_EXTERNAL_WALLET = 2
    
    static let NETWORK_ERROR = 0
    static let INVALID_OPTIONS = 1
    static let PAYMENT_CANCELLED = 2
    static let TLS_ERROR = 3
    static let INCOMPATIBLE_PLUGIN = 3
    static let UNKNOWN_ERROR = 100
    
    public func onExternalWalletSelected(_ walletName: String, withPaymentData paymentData: [AnyHashable : Any]?) {
        var response = [String:Any]()
        response["type"] = RazorpayDelegate.CODE_PAYMENT_EXTERNAL_WALLET
        
        var data = [String:Any]()
        data["external_wallet"] = walletName
        response["data"] = data
        
        complete(response as NSDictionary)
    }
    
    private var pendingResult: FlutterResult?
    private var pendingOptions: Dictionary<String, Any>?
    private var razorpay: RazorpayCheckout?
    private var subscribedAnalyticsEvents: [String]?
    var merchantEventSink: FlutterEventSink?

    private let logTag = "RazorpayFlutter"

    override public init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenUrlNotification(_:)),
            name: Notification.Name("RazorpayFlutterOpenUrl"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func subscribeToAnalyticsEvents(events: [String]) {
        subscribedAnalyticsEvents = events
    }

    public func onEvent(_ payloadJson: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let sink = self.merchantEventSink else {
            NSLog("[RazorpayFlutter] Analytics event received but Flutter listener is not connected")
                return
            }
            sink(payloadJson)
        }
    }

    @objc private func handleOpenUrlNotification(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? String else { return }
        NSLog("[RazorpayFlutter] publishUri received url=\(url)")
        do {
            try razorpay?.publishUri(with: url)
            NSLog("[RazorpayFlutter] publishUri completed")
        } catch {
            NSLog("[RazorpayFlutter] publishUri failed: \(error)")
        }
    }

    public func onPaymentError(_ code: Int32, description message: String, andData data: [AnyHashable : Any]?) {
        NSLog("[RazorpayFlutter] onPaymentError code=\(code) message=\(message)")
        var response = [String:Any]()
        response["type"] = RazorpayDelegate.CODE_PAYMENT_ERROR
        
        var errorData = [String:Any]()
        errorData["code"] = RazorpayDelegate.translateRzpPaymentError(errorCode: Int(code))
        errorData["message"] = message 
        errorData["responseBody"] = data
        
        response["data"] = errorData
        complete(response as NSDictionary)
    }

    public func onPaymentError(_ code: Int32, description message: String) {
        onPaymentError(code, description: message, andData: nil)
    }
    
    public func onPaymentSuccess(_ payment_id: String, andData data: [AnyHashable: Any]?) {
        NSLog("[RazorpayFlutter] onPaymentSuccess payment_id=\(payment_id)")
        var response = [String:Any]()
        response["type"] = RazorpayDelegate.CODE_PAYMENT_SUCCESS
        response["data"] = data
        
        complete(response as NSDictionary)
    }

    public func onPaymentSuccess(_ payment_id: String) {
        NSLog("[RazorpayFlutter] onPaymentSuccess payment_id=\(payment_id)")
        let orderId = (pendingOptions?["order_id"] as? String) ?? ""
        complete([
            "type": RazorpayDelegate.CODE_PAYMENT_SUCCESS,
            "data": [
                "razorpay_payment_id": payment_id,
                "razorpay_order_id": orderId,
                "razorpay_signature": ""
            ]
        ] as NSDictionary)
    }
    
    public func open(options: Dictionary<String, Any>, result: @escaping FlutterResult, from viewController: UIViewController?) {
        NSLog("[RazorpayFlutter] open called hasViewController=\(viewController != nil)")
        if pendingResult != nil {
            complete([
                "type": RazorpayDelegate.CODE_PAYMENT_ERROR,
                "data": [
                    "code": RazorpayDelegate.UNKNOWN_ERROR,
                    "message": "Another Razorpay payment is already in progress"
                ]
            ] as NSDictionary)
        }
        self.pendingResult = result
        self.pendingOptions = options
        let key = options["key"] as? String
        razorpay = RazorpayCheckout.initWithKey(key ?? "", andDelegate: self)
        razorpay?.setExternalWalletSelectionDelegate(self)
        var options = options
        options["integration"] = "flutter"
        options["FRAMEWORK"] = "flutter"
        if let vc = viewController {
            razorpay?.open(options, displayController: vc)
        } else {
            razorpay?.open(options)
        }
    }
    
    public func resync(result: @escaping FlutterResult) {
        result(nil)
    }

    public func closeCheckout(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(nil)
                return
            }
            self.razorpay?.close()
            self.complete([
                "type": RazorpayDelegate.CODE_PAYMENT_ERROR,
                "data": [
                    "code": RazorpayDelegate.PAYMENT_CANCELLED,
                    "message": "Razorpay checkout was closed"
                ]
            ] as NSDictionary)
            result(nil)
        }
    }
    
    static func translateRzpPaymentError(errorCode: Int) -> Int {
        switch (errorCode) {
        case 0:
            return NETWORK_ERROR
        case 1:
            return INVALID_OPTIONS
        case 2:
            return PAYMENT_CANCELLED
        default:
            return UNKNOWN_ERROR
        }
    }

    private func complete(_ response: NSDictionary) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.complete(response)
            }
            return
        }

        guard let result = pendingResult else { return }
        NSLog("[RazorpayFlutter] completing response=\(response)")
        pendingResult = nil
        pendingOptions = nil
        result(safeForFlutter(response))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.razorpay = nil
        }
    }

    private func safeForFlutter(_ value: Any?) -> Any {
        guard let value = value else { return NSNull() }

        if value is NSNull ||
            value is NSString ||
            value is NSNumber ||
            value is String ||
            value is Int ||
            value is Double ||
            value is Bool {
            return value
        }

        if let dictionary = value as? NSDictionary {
            var safeDictionary = [String: Any]()
            for (key, nestedValue) in dictionary {
                safeDictionary[String(describing: key)] = safeForFlutter(nestedValue)
            }
            return safeDictionary
        }

        if let dictionary = value as? [AnyHashable: Any] {
            var safeDictionary = [String: Any]()
            for (key, nestedValue) in dictionary {
                safeDictionary[String(describing: key)] = safeForFlutter(nestedValue)
            }
            return safeDictionary
        }

        if let array = value as? NSArray {
            return array.map { safeForFlutter($0) }
        }

        if let array = value as? [Any] {
            return array.map { safeForFlutter($0) }
        }

        return String(describing: value)
    }
    
}
