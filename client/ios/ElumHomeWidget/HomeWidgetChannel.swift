import Flutter
import WidgetKit

// 앱(Runner) 타깃에 넣을 채널: Dart HomeWidgetBridge(elum/home_widget) > App Group UserDefaults 저장 > 위젯 새로 그림
// 지금은 어느 타깃에도 들어 있지 않음 (위젯 확장·App Group 을 Xcode 에서 붙인 뒤 Runner 에 추가)
// 등록: AppDelegate.didInitializeImplicitFlutterEngine 에서
//   HomeWidgetChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
enum HomeWidgetChannel {
  static let channelName = "elum/home_widget"
  // ElumHomeWidget.swift ElumHomeWidgetStore 와 같은 값
  static let appGroupId = "group.kr.twinfang.elum"
  static let snapshotKey = "elum.lockScreenSnapshot"

  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "updateSnapshot" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
          result(FlutterError(code: "E-WIDGET-GROUP", message: "App Group unavailable", details: nil))
          return
        }
        // json 이 없으면(로그아웃) 지움
        let arguments = call.arguments as? [String: Any]
        if let json = arguments?["json"] as? String {
          defaults.set(json, forKey: snapshotKey)
        } else {
          defaults.removeObject(forKey: snapshotKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      }
  }
}
