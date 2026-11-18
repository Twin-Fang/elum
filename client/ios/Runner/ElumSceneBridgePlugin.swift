import Flutter
import NidThirdPartyLogin
import UIKit

/// scene 이벤트 앱 쪽 처리: 네이버 로그인 콜백 URL, 홈 화면 위젯 URL(#1465), 옛 플러그인용 AppDelegate.window 연결
/// Info.plist FlutterSceneDelegate > 등록 순서대로 플러그인 scene 대리자 호출 > 아무도 안 받으면 Flutter 라우터(딥링크)
final class ElumSceneBridgePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static let pluginKey = "ElumSceneBridge"

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ElumSceneBridgePlugin()
    // scene 대리자 목록은 약한 참조 > publish 로 엔진이 인스턴스를 붙잡게 함
    registrar.publish(instance)
    registrar.addSceneDelegate(instance)
  }

  /// scene 연결 시 AppDelegate.window 를 scene 창으로 채움
  /// printing·광고 동의 창은 아직 AppDelegate.window 로 화면을 찾음 (scene 에서는 nil)
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
       appDelegate.window == nil,
       let sceneWindow = (scene.delegate as? UIWindowSceneDelegate)?.window ?? nil {
      appDelegate.window = sceneWindow
    }
    // 위젯을 눌러 켠 경우: 경로를 위젯 채널에 넘기고 Flutter 라우터에는 주지 않음
    if connectionOptions?.urlContexts.contains(where: { HomeWidgetChannel.open(url: $0.url) }) == true {
      return true
    }
    // false: 시작 URL·유니버설 링크를 Flutter 라우터가 계속 받게 둠
    return false
  }

  /// 외부 앱 복귀 URL 중 홈 화면 위젯 · 네이버 로그인 콜백만 처리
  /// false 면 다음 대리자·Flutter 라우터로 넘어감 (elum://invite 등 같은 scheme 링크)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var isHandled = false
    for context in URLContexts
    where HomeWidgetChannel.open(url: context.url) || NidOAuth.shared.handleURL(context.url) {
      isHandled = true
    }
    return isHandled
  }
}
