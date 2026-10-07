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
    // rootViewController 형변환에 기대면 실패 시 채널이 없어 앱이 설치 오류 화면에 갇힌다.
    if let registrar = self.registrar(forPlugin: "ElumInstallation") {
      FlutterMethodChannel(name: "elum/installation", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "getInstallationId" else {
            result(FlutterMethodNotImplemented)
            return
          }
          do { result(try Self.installationId()) }
          catch { result(FlutterError(code: "E-INSTALL", message: "Installation marker unavailable", details: nil)) }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
