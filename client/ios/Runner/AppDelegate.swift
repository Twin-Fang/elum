import Flutter
import google_mobile_ads
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 일과 알림 (#777): 앱이 떠 있을 때도 알림 배너가 보이게 알림 센터 대리자를 잡는다
    // (실행 완료 전에 잡아야 함 > scene 연결 시점이 아니라 여기)
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// scene 창의 FlutterViewController 가 엔진을 만든 직후: 플러그인 > 광고 팩토리 > 앱 채널 등록
  /// scene 에서는 실행 시점에 엔진이 없음 > didFinishLaunching 에서 등록하면 채널이 비어 버림
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let pluginRegistry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: pluginRegistry)
    // 네이버 로그인 콜백 URL · 옛 플러그인용 창 연결
    if let registrar = pluginRegistry.registrar(forPlugin: ElumSceneBridgePlugin.pluginKey) {
      ElumSceneBridgePlugin.register(with: registrar)
    }
    // 하단 한 줄 광고 띠 팩토리 (#743). Dart NativeAd 의 factoryId 가 이 이름을 찾는다
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      pluginRegistry,
      factoryId: StripNativeAdFactory.factoryId,
      nativeAdFactory: StripNativeAdFactory()
    )
    // 채널이 없으면 앱이 설치 오류 화면에 갇힌다 > 화면 컨트롤러 대신 엔진 messenger 로 만든다
    FlutterMethodChannel(name: "elum/installation", binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "getInstallationId" else {
          result(FlutterMethodNotImplemented)
          return
        }
        do { result(try Self.installationId()) }
        catch { result(FlutterError(code: "E-INSTALL", message: "Installation marker unavailable", details: nil)) }
      }
  }

  private static func installationId() throws -> String {
    let manager = FileManager.default
    let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                  appropriateFor: nil, create: true)
    var directory = support.appendingPathComponent("ElumInstallation", isDirectory: true)
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    // 삭제 후 Keychain은 남아도 백업 제외 설치 표식은 복원되지 않아야 한다.
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
    var file = directory.appendingPathComponent("installation-id")
    var existing: String?
    do {
      existing = try String(contentsOf: file, encoding: .utf8)
    } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
      // 파일이 없을 때만 새 설치로 본다. 다른 읽기 오류는 그대로 던진다.
      existing = nil
    }
    let id: String
    if let existing = existing {
      guard UUID(uuidString: existing) != nil else { throw NSError(domain: "E-INSTALL", code: 1) }
      id = existing
    } else {
      id = UUID().uuidString
      try id.write(to: file, atomically: true, encoding: .utf8)
    }
    try file.setResourceValues(values)
    return id
  }
}
