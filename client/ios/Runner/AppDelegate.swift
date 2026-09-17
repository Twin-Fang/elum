import Flutter
import NidThirdPartyLogin
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 로그인을 마친 외부 앱이 우리 앱을 다시 열 때 들어온다.
  ///
  /// 네이버는 SDK가 직접 처리해야 하므로 먼저 넘긴다. 네이버 것이 아니면
  /// super로 넘겨 다른 플러그인(카카오·구글)이 처리하게 둔다.
  /// 여기서 곧바로 false를 돌려주면 다른 소셜 로그인이 콜백을 받지 못한다.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if NidOAuth.shared.handleURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
