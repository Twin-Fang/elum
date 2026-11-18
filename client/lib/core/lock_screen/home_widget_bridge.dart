import 'dart:async';
import 'dart:convert';

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
  final StreamController<void> _checksAddedController = StreamController<void>.broadcast();

  /// 마지막으로 보낸 요약 (같은 값이면 다시 보내지 않음)
  String? _lastPushedJson;

  /// 앱이 떠 있을 때 위젯을 눌러 연 경로 (`home` · `routine:<id>`)
  Stream<String> get openedRoutes => _routeController.stream;

  /// 앱이 떠 있을 때 위젯에서 카드를 체크함 (Android, 신호만 · 내용은 [takeWidgetChecks])
  Stream<void> get widgetChecksAdded => _checksAddedController.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'widgetChecksAdded') {
      _checksAddedController.add(null);
      return null;
    }
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

  /// 위젯에서 체크해 둔 카드 꺼내기 (꺼내면 비움). 깨졌거나 없으면 빈 목록 (#1465 2단계)
  Future<List<WidgetCardCheck>> takeWidgetChecks() async {
    final json = await _invoke<String>('takeWidgetChecks');
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?WidgetCardCheck.fromJson(item)];
    } catch (error) {
      AppLogger.error('home widget', 'takeWidgetChecks parse failed : $error');
      return const [];
    }
  }

  /// 개발자 도구: 홈 화면에 위젯 고정 요청 (Android, kind: today · now_card · streak) · 런처가 지원하면 true
  Future<bool> requestPinWidget(String kind) async =>
      await _invoke<bool>('requestPinWidget', {'kind': kind}) ?? false;

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

/// 위젯에서 체크한 카드 한 건 (네이티브 대기열 `elum.widget.checkOutbox` 항목)
@immutable
class WidgetCardCheck {
  const WidgetCardCheck({required this.routineId, required this.cardId, required this.dateKey});

  final String routineId;
  final String cardId;

  /// 체크한 날 (`yyyy-MM-dd`, 오늘이 아니면 버림)
  final String dateKey;

  static WidgetCardCheck? fromJson(Object? json) {
    if (json is! Map) return null;
    final routineId = json['routineId'];
    final cardId = json['cardId'];
    final dateKey = json['dateKey'];
    if (routineId is! String || cardId is! String || dateKey is! String) return null;
    return WidgetCardCheck(routineId: routineId, cardId: cardId, dateKey: dateKey);
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => HomeWidgetBridge(),
);
