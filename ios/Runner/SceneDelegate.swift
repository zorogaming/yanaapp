import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      forwardRazorpayUrl(context.url.absoluteString, source: "SceneDelegate.openURLContexts")
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL?.absoluteString {
      forwardRazorpayUrl(url, source: "SceneDelegate.continueUserActivity")
    }
    super.scene(scene, continue: userActivity)
  }

  private func forwardRazorpayUrl(_ url: String, source: String) {
    NSLog("[RazorpayFlutter] \(source) url=\(url)")
    NotificationCenter.default.post(
      name: Notification.Name("RazorpayFlutterOpenUrl"),
      object: nil,
      userInfo: ["url": url]
    )
  }
}
