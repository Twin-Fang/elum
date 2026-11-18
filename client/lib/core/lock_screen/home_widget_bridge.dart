import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';
import 'lock_screen_snapshot.dart';

/// 홈 화면 위젯 채널(elum/home_widget) 래퍼: 오늘 요약 저장 > 위젯 새로 그림 · 위젯을 눌러 연 경로 받기
/// iOS(WidgetKit) · Android(AppWidget) 공통 (#1465). 네이티브 쪽이 없으면 MissingPluginException 을 조용히 넘김
class HomeWidgetBridge {
  HomeWidgetBridge({MethodChannel? channel, bool? isSupported})
    : _channel = channel ?? const MethodChannel(_channelName),
      isSupported =
          isSupported ??
          (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android)) {
    if (this.isSupported) _channel.setMethodCallHandler(_onNativeCall);
  }

  static const String _channelName = 'elum/home_widget';

  final MethodChannel _channel;
  final bool isSupported;

  final StreamController<String> _routeController = StreamController<String>.broadcast();

  /// 마지막으로 보낸 요약 (같은 값이면 다시 보내지 않음)
  String? _lastPushedJson;

  /// 앱이 떠 있을 때 위젯을 눌러 연 경로 (`home` · `routine:<id>`)
  Stream<String> get openedRoutes => _routeController.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method != 'openRoute') return null;
    final route = (call.arguments as Map?)?['route'];
    if (route is String && route.isNotEmpty) _routeController.add(route);
    return null;
  }

  /// 오늘 요약 저장 (null 이면 지움 · 로그아웃)
  Future<void> updateSnapshot(LockScreenSnapshot? snapshot) async {
    if (!isSupported) return;
    final json = snapshot?.toJsonString();
    if (json == _lastPushedJson) return;
    _lastPushedJson = json;
    await _invoke<void>('updateSnapshot', {'json': json});
  }

  /// 위젯을 눌러 앱을 켠 경우의 경로 (꺼내면 비움, 없으면 null)
  Future<String?> takePendingRoute() => _invoke<String>('takePendingRoute');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      AppLogger.error('home widget', '$method failed : ${error.code}');
    } on MissingPluginException {
      // 위젯 네이티브 쪽이 아직 붙지 않은 빌드
    }
    return null;
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => HomeWidgetBridge(),
);
