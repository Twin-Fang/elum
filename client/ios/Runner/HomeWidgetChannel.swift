import Flutter
import WidgetKit

// 앱(Runner) 채널: Dart HomeWidgetBridge(elum/home_widget) <> 홈 화면 위젯 (#1410, #1465)
// 메서드 4개: updateSnapshot(요약 저장 > 위젯 새로 그림) · takePendingRoute(위젯으로 켠 경로) · takeWidgetChecks(위젯 체크 대기열) · openRoute(네이티브 > Dart)
// 등록: AppDelegate.didInitializeImplicitFlutterEngine · 위젯 URL: ElumSceneBridgePlugin 이 open(url:) 로 넘김
enum HomeWidgetChannel {
  static let channelName = "elum/home_widget"
  // ElumWidgetModel.swift ElumWidgetStore 와 같은 값
  static let appGroupId = "group.kr.twinfang.elum"
  static let snapshotKey = "elum.lockScreenSnapshot"
  // 위젯이 읽을 카드 그림 사본 (App Group 컨테이너 안, 위젯 확장은 앱 폴더를 못 읽음)
  static let cardImageFileName = "widget-card.png"
  // 위젯 URL: elum://widget?route=home | routine:<id> | check:<일과>:<카드>
  static let urlHost = "widget"
  // 위젯 체크 저장 키 (ElumWidgetCheck.swift ElumWidgetCheckStore 와 같은 값, #1465 2단계)
  static let checkOutboxKey = "elum.widget.checkOutbox"
  static let checkedCardIdsKey = "elum.widget.checkedCardIds"

  private static var channel: FlutterMethodChannel?
  // 위젯을 눌러 앱을 켰는데 Dart 가 아직 듣지 않을 때 보관 (Dart 가 takePendingRoute 로 꺼내면 비움)
  private static var pendingRoute: String?

  static func register(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "updateSnapshot":
        updateSnapshot(arguments: call.arguments, result: result)
      case "takePendingRoute":
        result(pendingRoute)
        pendingRoute = nil
      case "takeWidgetChecks":
        // 위젯이 쌓은 체크 꺼내고 비움 (없으면 "[]")
        let defaults = UserDefaults(suiteName: appGroupId)
        result(defaults?.string(forKey: checkOutboxKey) ?? "[]")
        defaults?.removeObject(forKey: checkOutboxKey)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = methodChannel
  }

  /// 위젯 URL 이면 경로를 Dart 로 넘기고 true (그 밖의 URL 은 false > 다음 처리기)
  static func open(url: URL) -> Bool {
    guard url.scheme == "elum", url.host == urlHost else { return false }
    let route = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "route" })?.value ?? "home"
    // 막 켠 앱은 Dart 가 아직 안 들음 > 보관 + 떠 있는 앱은 바로 전달 (둘 다 같은 경로라 한 번만 열림)
    pendingRoute = route
    channel?.invokeMethod("openRoute", arguments: ["route": route])
    return true
  }

  // 요약 저장: 카드 그림을 App Group 으로 복사해 경로를 바꿔 넣음 > 저장 > 위젯 새로 그림 (json 없으면 지움)
  private static func updateSnapshot(arguments: Any?, result: FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupId) else {
      result(FlutterError(code: "E-WIDGET-GROUP", message: "App Group unavailable", details: nil))
      return
    }
    let json = (arguments as? [String: Any])?["json"] as? String
    if let json = json {
      defaults.set(snapshotWithSharedCardImage(json), forKey: snapshotKey)
    } else {
      defaults.removeObject(forKey: snapshotKey)
    }
    // 새 요약이 기준 > 위젯이 표시용으로 넘긴 카드 목록은 비움
    defaults.removeObject(forKey: checkedCardIdsKey)
    WidgetCenter.shared.reloadAllTimelines()
    result(nil)
  }

  // elumiCard · upcomingCards 의 imageFilePath(앱 폴더) > App Group 사본 경로. 복사 실패면 경로를 비움 (위젯은 루미 그림으로 대신)
  private static func snapshotWithSharedCardImage(_ json: String) -> String {
    guard
      let data = json.data(using: .utf8),
      var snapshot = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      var card = snapshot["elumiCard"] as? [String: Any]
    else { return json }
    card["imageFilePath"] = copyCardImageToAppGroup(card["imageFilePath"] as? String, fileName: cardImageFileName) ?? NSNull()
    if let upcomingCards = card["upcomingCards"] as? [[String: Any]] {
      card["upcomingCards"] = upcomingCards.enumerated().map { index, upcoming -> [String: Any] in
        var copied = upcoming
        copied["imageFilePath"] = copyCardImageToAppGroup(
          upcoming["imageFilePath"] as? String, fileName: "widget-card-next-\(index).png"
        ) ?? NSNull()
        return copied
      }
    }
    snapshot["elumiCard"] = card
    guard let updated = try? JSONSerialization.data(withJSONObject: snapshot),
          let updatedJson = String(data: updated, encoding: .utf8)
    else { return json }
    return updatedJson
  }

  private static func copyCardImageToAppGroup(_ sourcePath: String?, fileName: String) -> String? {
    let manager = FileManager.default
    guard
      let sourcePath = sourcePath, !sourcePath.isEmpty, manager.fileExists(atPath: sourcePath),
      let container = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    else { return nil }
    let target = container.appendingPathComponent(fileName)
    do {
      if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
      try manager.copyItem(at: URL(fileURLWithPath: sourcePath), to: target)
      return target.path
    } catch {
      NSLog("[home widget] card image copy failed : %@", error.localizedDescription)
      return nil
    }
  }
}
