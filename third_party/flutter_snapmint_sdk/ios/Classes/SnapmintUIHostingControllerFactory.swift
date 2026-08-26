import Foundation
import SwiftUI
import SnapmintMerchantSdk

@objc(SnapmintUIHostingControllerFactory)
public class SnapmintUIHostingControllerFactory: NSObject {
    @objc public static func hostingController(for url: NSURL,
                                               resultHandler: @escaping (Any?) -> Void) -> UIViewController {
        if #available(iOS 13.0, *) {
            NSLog("[SnapmintUIHostingControllerFactory] Creating UIHostingController for url=%@", url.absoluteString ?? "")
            let bridge = CheckoutBridgeView(url: url as URL, headerConfig: nil, callback: resultHandler)
            let host = UIHostingController(rootView: bridge)
            host.modalPresentationStyle = .fullScreen
            return host
        } else {
            return UIViewController()
        }
    }

    @objc public static func hostingController(for url: NSURL,
                                               header: [String: Any]?,
                                               resultHandler: @escaping (Any?) -> Void) -> UIViewController {
        if #available(iOS 13.0, *) {
            NSLog("[SnapmintUIHostingControllerFactory] Creating UIHostingController for url=%@ with header=%@", url.absoluteString ?? "", String(describing: header))
            let headerConfig = Self.makeHeaderConfig(from: header)
            let bridge = CheckoutBridgeView(url: url as URL, headerConfig: headerConfig, callback: resultHandler)
            let host = UIHostingController(rootView: bridge)
            host.modalPresentationStyle = .fullScreen
            return host
        } else {
            return UIViewController()
        }
    }

    private static func makeHeaderConfig(from dict: [String: Any]?) -> SnapmintMerchantSdk.SnapmintHeaderConfig? {
        guard let dict = dict else { return nil }
        let enableHeader = (dict["enableHeader"] as? Bool) ?? false
        guard enableHeader else { return nil }

        
        let showTitle = (dict["showTitle"] as? Bool) ?? false
        let title = showTitle ? (dict["title"] as? String ?? "Snapmint") : nil
        let backButtonColor = dict["backButtonColor"] as? String
        let titleColor = dict["titleColor"] as? String
        let headerColor = dict["headerColor"] as? String

        let backImage: Image? = nil
        let logo: Image? = nil

        return SnapmintMerchantSdk.SnapmintHeaderConfig(
            backButtonImage: backImage,
            backButtonColor: backButtonColor,
            logo: logo,
            title: title,
            titleColor: titleColor,
            headerColor: headerColor
        )
    }
}

@available(iOS 13.0, *)
extension SnapmintMerchantSdk.SnapmintOrderResult: Equatable {
    public static func == (lhs: SnapmintMerchantSdk.SnapmintOrderResult, rhs: SnapmintMerchantSdk.SnapmintOrderResult) -> Bool {
        lhs.status == rhs.status && lhs.message == rhs.message
    }
}

import Combine

@available(iOS 13.0, *)
private struct CheckoutBridgeView: View {
    let url: URL
    let headerConfig: SnapmintMerchantSdk.SnapmintHeaderConfig?
    @State private var result: SnapmintMerchantSdk.SnapmintOrderResult? = nil
    @State private var hasSent: Bool = false
    let callback: (Any?) -> Void

    var body: some View {
        let baseView = SnapmintMerchantSdk.SnapmintCheckoutView(headerConfig: headerConfig, url: url, result: $result)
        if #available(iOS 14.0, *) {
            return AnyView(baseView.onChange(of: result) { newValue in
                if let r = newValue {
                    NSLog("[CheckoutBridgeView] onChange -> status=%@, message=%@", r.status, r.message)
                    if !hasSent {
                        hasSent = true
                        let payload: [String: Any] = [
                            "status": r.status,
                            "message": r.message,
                            "data": r.data
                        ]
                        callback(payload)
                    } else {
                        NSLog("[CheckoutBridgeView] onChange -> duplicate result ignored")
                    }
                } else {
                    NSLog("[CheckoutBridgeView] onChange -> nil result (ignored)")
                }
            })
        } else {
            return AnyView(baseView.onReceive(Just(result)) { newValue in
                if let r = newValue {
                    NSLog("[CheckoutBridgeView] onReceive -> status=%@, message=%@", r.status, r.message)
                    if !hasSent {
                        hasSent = true
                        let payload: [String: Any] = [
                            "status": r.status,
                            "message": r.message,
                            "data": r.data
                        ]
                        callback(payload)
                    } else {
                        NSLog("[CheckoutBridgeView] onReceive -> duplicate result ignored")
                    }
                } else {
                    NSLog("[CheckoutBridgeView] onReceive -> nil result (ignored)")
                }
            })
        }
    }
}

