import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';
import 'lock_screen_snapshot.dart';

/// iOS 홈 화면 위젯 채널(elum/home_widget) 래퍼: 보호자 오늘 진행 요약을 App Group 에 저장 > 위젯 새로 그림
/// iOS 전용. 네이티브 쪽(위젯 확장·App Group)이 아직 없으면 MissingPluginException 을 조용히 넘김
class HomeWidgetBridge {
  HomeWidgetBridge({MethodChannel? channel, bool? isSupported})
    : _channel = channel ?? const MethodChannel(_channelName),
      _isSupported =
          isSupported ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static const String _channelName = 'elum/home_widget';

  final MethodChannel _channel;
  final bool _isSupported;

  /// 마지막으로 보낸 요약 (같은 값이면 다시 보내지 않음)
  String? _lastPushedJson;

  /// 오늘 진행 요약 저장 (null 이면 지움 · 로그아웃)
  Future<void> updateSnapshot(LockScreenSnapshot? snapshot) async {
    if (!_isSupported) return;
    final json = snapshot?.toJsonString();
    if (json == _lastPushedJson) return;
    _lastPushedJson = json;
    try {
      await _channel.invokeMethod<void>('updateSnapshot', {'json': json});
    } on PlatformException catch (error) {
      AppLogger.error('home widget', 'updateSnapshot failed : ${error.code}');
    } on MissingPluginException {
      // 위젯 확장이 아직 붙지 않은 빌드
    }
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => HomeWidgetBridge(),
);
